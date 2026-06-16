(local commands (require :app.commands))
(local git (require :git.core))
(local preview (require :preview.core))
(local preview-warm (require :preview.warm))
(local reviews (require :storage.reviews))
(local search (require :app.search))
(local sync (require :git.sync))
(local theme (require :tui.theme))

(fn selected-entry [state]
  (. state.entries state.selected))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn set-selection [state selected]
  (let [before state.selected]
    (set state.selected selected)
    (when (not (= before state.selected))
      (preview.reset-scroll state))))

(fn reviewed-count [entries]
  (accumulate [count 0 _ entry (ipairs entries)]
    (if entry.reviewed (+ count 1) count)))

(fn event-key [key]
  (case key
    :up :up
    :down :down
    :enter :open
    :quit :quit
    :tick :tick
    "k" :up
    "j" :down
    "o" :open
    " " :toggle-reviewed
    "a" :toggle-all-reviewed
    "\4" :preview-down
    "\21" :preview-up
    "/" :search
    "n" :search-next
    "N" :search-previous
    "r" :refresh
    "R" :sync
    "y" :copy-path
    "p" :open-pr
    "<" :split-left
    ">" :split-right
    "G" :bottom
    "q" :clear-search
    _ key))

(fn next-key [?pending-key key]
  (let [key (event-key key)]
    (if (and (= ?pending-key "g") (= key "g")) (values nil :top)
        (= key "g") (values "g" nil)
        (values nil key))))

(fn read-msg [state raw-key]
  (if (= raw-key :quit)
      {:type :quit}
      (search.active? state)
      {:type :search-input :key raw-key}
      (let [(pending-key action) (next-key state.pending-key raw-key)]
        (if action
            {:type action :pending-key pending-key}
            {:type :pending-key :pending-key pending-key}))))

(fn move-selection [state delta]
  (let [entries state.entries
        selected (if (= (length entries) 0)
                     1
                     (clamp (+ state.selected delta) 1 (length entries)))]
    (set-selection state selected)))

(fn set-notice [state action path]
  (set state.notice (.. action ": " path)))

(fn reviewed-action [entry]
  (if entry.reviewed "Marked reviewed" "Unmarked reviewed"))

(fn toggle-reviewed [state]
  (let [entry (selected-entry state)]
    (when entry
      (set entry.reviewed (not entry.reviewed))
      (set-notice state (reviewed-action entry) entry.path)))
  (commands.persist-reviewed))

(fn toggle-all-reviewed [state]
  (let [entries state.entries
        reviewed (reviewed-count entries)
        review? (< reviewed (length entries))]
    (each [_ entry (ipairs entries)]
      (set entry.reviewed review?))
    (set state.notice (if review?
                          "Marked all reviewed"
                          "Unmarked all reviewed"))
    (commands.persist-reviewed)))

(fn jump-top [state]
  (set-selection state 1))

(fn jump-bottom [state]
  (let [last (length state.entries)]
    (set-selection state last)))

(fn cache-selected-preview [state]
  (preview.lines state (selected-entry state))
  state)

(fn apply-refresh [state entries reviewed]
  (set state.entries (reviews.apply entries reviewed))
  (preview.reset-scroll state)
  (move-selection state 0)
  (cache-selected-preview state)
  (commands.batch (commands.warm-preview-cache) (commands.persist-reviewed)))

(fn open-selected [state config]
  (let [entry (selected-entry state)]
    (when entry
      (set-notice state "Opening" entry.path)
      (commands.open-editor config entry))))

(fn copy-selected-path [state]
  (let [entry (selected-entry state)]
    (when entry
      (commands.copy-path entry.path))))

(fn move-split [state delta]
  (set state.split_ratio (clamp (+ (or state.split_ratio 0.4) delta) 0.1 0.9)))

(local action-handlers
       {:up #(move-selection $1 -1)
        :down #(move-selection $1 1)
        :open open-selected
        :toggle-reviewed toggle-reviewed
        :toggle-all-reviewed toggle-all-reviewed
        :preview-down #(preview.scroll-page-down $1 (selected-entry $1))
        :preview-up #(preview.scroll-page-up $1 (selected-entry $1))
        :search search.start
        :search-next search.next
        :search-previous search.previous
        :clear-search search.clear
        :top jump-top
        :bottom jump-bottom
        :refresh commands.refresh
        :sync commands.sync-start
        :copy-path copy-selected-path
        :open-pr commands.open-linked-pr
        :split-left #(move-split $1 -0.05)
        :split-right #(move-split $1 0.05)})

(fn update [state config msg]
  (let [msg-type (and (= (type msg) :table) msg.type)
        command (case msg-type
                  :quit (do
                          (set state.quit? true)
                          commands.none)
                  :pending-key (do
                                 (set state.pending-key msg.pending-key)
                                 commands.none)
                  :search-input (do
                                  (search.handle-input state msg.key)
                                  commands.none)
                  :review-persist-failed (do
                                           (set state.notice
                                                "Could not save reviewed marks")
                                           commands.none)
                  :copy-path-finished (do
                                        (set-notice state
                                                    (if msg.ok?
                                                        "Copied"
                                                        "Copy failed")
                                                    msg.path)
                                        commands.none)
                  :open-pr-finished (do
                                      (set state.notice
                                           (if msg.ok?
                                               (.. "Opened PR: " msg.url)
                                               (or msg.error "No linked PR")))
                                      commands.none)
                  :refresh-loaded (apply-refresh state msg.entries msg.reviewed)
                  _ (do
                      (set state.pending-key msg.pending-key)
                      (let [handler (. action-handlers msg-type)]
                        (if handler
                            (or (handler state config) commands.none)
                            commands.none))))]
    (values state command)))

(fn run-command [state config command]
  (let [queue []]
    (fn dispatch [msg]
      (when msg
        (table.insert queue msg)))

    (fn get-state []
      state)

    (when command
      (command dispatch get-state))
    (while (> (length queue) 0)
      (let [msg (table.remove queue 1)
            (_ next-command) (update state config msg)]
        (when next-command
          (next-command dispatch get-state)))))
  state)

(fn init [revision entries review-store review-scope src-dir]
  {:revision revision
   :src_dir src-dir
   :revision_label (git.comparison-label revision)
   :entries entries
   :quit? false
   :selected 1
   :preview_scroll 0
   :preview_rows 1
   :preview_total 0
   :split_ratio 0.4
   :theme theme.default
   :preview_cache {}
   :preview_context (git.preview-context)
   :preview_warm (preview-warm.new-state)
   :review_store review-store
   :review_scope review-scope
   :search (search.new-state)
   :sync (sync.new-state revision)
   :pending-key nil})

(fn handle-key [state config raw-key]
  (when (= raw-key :tick)
    (sync.update state.sync)
    (preview-warm.update state.preview_warm state.preview_cache))
  (let [(_ command) (update state config (read-msg state raw-key))]
    (run-command state config command))
  (not state.quit?))

(fn start [state]
  (cache-selected-preview state)
  (run-command state {} (commands.warm-preview-cache)))

{: cache-selected-preview
 : handle-key
 : init
 :new-state init
 : read-msg
 : run-command
 : start
 : update}
