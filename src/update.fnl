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

(fn warm-preview-cache [state]
  (preview-warm.start state.preview_warm state.src_dir state.revision
                      state.entries))

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

(fn persist-reviewed [state]
  (when (not (reviews.persist state.review_store state.review_scope
                              state.entries))
    (set state.notice "Could not save reviewed marks")))

(fn reviewed-action [entry]
  (if entry.reviewed "Marked reviewed" "Unmarked reviewed"))

(fn toggle-reviewed [state]
  (let [entry (selected-entry state)]
    (when entry
      (set entry.reviewed (not entry.reviewed))
      (set-notice state (reviewed-action entry) entry.path)
      (persist-reviewed state))))

(fn toggle-all-reviewed [state]
  (let [entries state.entries
        reviewed (reviewed-count entries)
        review? (< reviewed (length entries))]
    (each [_ entry (ipairs entries)]
      (set entry.reviewed review?))
    (set state.notice (if review?
                          "Marked all reviewed"
                          "Unmarked all reviewed"))
    (persist-reviewed state)))

(fn jump-top [state]
  (set-selection state 1))

(fn jump-bottom [state]
  (let [last (length state.entries)]
    (set-selection state last)))

(fn refresh-state [state]
  (let [reviewed (reviews.paths state.entries)
        (entries err) (git.diff-entries state.revision)]
    (when (not err)
      (set state.entries (reviews.apply entries reviewed))
      (set state.preview_cache {})
      (warm-preview-cache state)
      (preview.reset-scroll state)
      (move-selection state 0)
      (persist-reviewed state)
      (sync.start state.sync))))

(fn open-selected [state config]
  (let [entry (selected-entry state)]
    (when entry
      (set-notice state "Opened" entry.path)
      (editor.run config entry state.stty-state))))

(fn copy-selected-path [state]
  (let [entry (selected-entry state)]
    (when entry
      (if (clipboard.copy entry.path)
          (set-notice state "Copied" entry.path)
          (set-notice state "Copy failed" entry.path)))))

(fn continue-after [f]
  (f)
  true)

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
    :quit false
    _ true))

(fn update [state config msg]
  (case (and (= (type msg) :table) msg.type)
    :quit (set state.quit? true)
    :search-input (search.handle-input state msg.key)
    :key (do
           (set state.pending-key msg.pending-key)
           (let [running? (if msg.action
                              (handle-action state config msg.action)
                              true)]
             (when (= running? false)
               (set state.quit? true)))))
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
  (update state config (read-msg state raw-key))
  (not state.quit?))

(fn start [state]
  (warm-preview-cache state)
  (sync.start state.sync))

{: handle-key : init :new-state init : read-msg : start : update}
