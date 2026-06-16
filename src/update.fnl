(local clipboard (require :clipboard))
(local editor (require :editor))
(local git (require :git))
(local preview (require :preview))
(local preview-warm (require :preview_warm))
(local reviews (require :reviews))
(local search (require :search))
(local sync (require :sync))

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

(fn none [_dispatch _get-state]
  nil)

(fn batch [...]
  (let [commands [...]]
    (fn [dispatch get-state]
      (each [_ command (ipairs commands)]
        (when command
          (command dispatch get-state))))))

(fn persist-reviewed-command []
  (fn [dispatch get-state]
    (let [state (get-state)]
      (when (not (reviews.persist state.review_store state.review_scope
                                  state.entries))
        (dispatch {:type :review-persist-failed})))))

(fn warm-preview-cache-command []
  (fn [_dispatch get-state]
    (let [state (get-state)]
      (preview-warm.start state.preview_warm state.src_dir state.revision
                          state.entries))))

(fn sync-start-command []
  (fn [_dispatch get-state]
    (let [state (get-state)]
      (sync.start state.sync))))

(fn open-editor-command [config entry]
  (fn [_dispatch get-state]
    (editor.run config entry (. (get-state) :stty-state))))

(fn copy-path-command [path]
  (fn [dispatch _get-state]
    (dispatch {:type :copy-path-finished :path path :ok? (clipboard.copy path)})))

(fn refresh-command []
  (fn [dispatch get-state]
    (let [state (get-state)
          reviewed (reviews.paths state.entries)
          (entries err) (git.diff-entries state.revision)]
      (when (not err)
        (dispatch {:type :refresh-loaded :entries entries :reviewed reviewed})))))

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
    "y" :copy-path
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
        {:type :key :pending-key pending-key :action action})))

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
  (persist-reviewed-command))

(fn toggle-all-reviewed [state]
  (let [entries state.entries
        reviewed (reviewed-count entries)
        review? (< reviewed (length entries))]
    (each [_ entry (ipairs entries)]
      (set entry.reviewed review?))
    (set state.notice (if review?
                          "Marked all reviewed"
                          "Unmarked all reviewed"))
    (persist-reviewed-command)))

(fn jump-top [state]
  (set-selection state 1))

(fn jump-bottom [state]
  (let [last (length state.entries)]
    (set-selection state last)))

(fn refresh-state [_state]
  (refresh-command))

(fn apply-refresh [state entries reviewed]
  (set state.entries (reviews.apply entries reviewed))
  (set state.preview_cache {})
  (preview.reset-scroll state)
  (move-selection state 0)
  (batch (warm-preview-cache-command) (persist-reviewed-command)
         (sync-start-command)))

(fn open-selected [state config]
  (let [entry (selected-entry state)]
    (when entry
      (set-notice state "Opened" entry.path)
      (open-editor-command config entry))))

(fn copy-selected-path [state]
  (let [entry (selected-entry state)]
    (when entry
      (copy-path-command entry.path))))

(fn continue-after [f]
  (or (f) none))

(fn handle-action [state config key]
  (case key
    :up (continue-after #(move-selection state -1))
    :down (continue-after #(move-selection state 1))
    :open (continue-after #(open-selected state config))
    :toggle-reviewed (continue-after #(toggle-reviewed state))
    :toggle-all-reviewed (continue-after #(toggle-all-reviewed state))
    :preview-down
    (continue-after #(preview.scroll-page-down state (selected-entry state)))
    :preview-up
    (continue-after #(preview.scroll-page-up state (selected-entry state)))
    :search (continue-after #(search.start state))
    :search-next (continue-after #(search.next state))
    :search-previous (continue-after #(search.previous state))
    :clear-search (continue-after #(search.clear state))
    :top (continue-after #(jump-top state))
    :bottom (continue-after #(jump-bottom state))
    :refresh (continue-after #(refresh-state state))
    :copy-path (continue-after #(copy-selected-path state))
    :tick (continue-after #nil)
    :quit (do
            (set state.quit? true)
            none)
    _ none))

(fn update [state config msg]
  (let [command (case (and (= (type msg) :table) msg.type)
                  :quit (do
                          (set state.quit? true)
                          none)
                  :search-input (do
                                  (search.handle-input state msg.key)
                                  none)
                  :key (do
                         (set state.pending-key msg.pending-key)
                         (if msg.action
                             (handle-action state config msg.action)
                             none))
                  :review-persist-failed (do
                                           (set state.notice
                                                "Could not save reviewed marks")
                                           none)
                  :copy-path-finished (do
                                        (set-notice state
                                                    (if msg.ok?
                                                        "Copied"
                                                        "Copy failed")
                                                    msg.path)
                                        none)
                  :refresh-loaded (apply-refresh state msg.entries msg.reviewed)
                  _ none)]
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
   :preview_cache {}
   :preview_context (git.preview-context)
   :preview_warm (preview-warm.new-state)
   :review_store review-store
   :review_scope review-scope
   :search (search.new-state)
   :sync (sync.new-state)
   :pending-key nil})

(fn handle-key [state config raw-key]
  (sync.update state.sync)
  (let [(_ command) (update state config (read-msg state raw-key))]
    (run-command state config command))
  (not state.quit?))

(fn start [state]
  (run-command state {} (batch (warm-preview-cache-command)
                               (sync-start-command))))

{: handle-key : init :new-state init : read-msg : run-command : start : update}
