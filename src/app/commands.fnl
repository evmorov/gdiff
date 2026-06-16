(local clipboard (require :platform.clipboard))
(local editor (require :platform.editor))
(local git (require :git.core))
(local preview-warm (require :preview.warm))
(local reviews (require :storage.reviews))
(local sync (require :git.sync))

(fn none [_dispatch _get-state]
  nil)

(fn batch [...]
  (let [commands [...]]
    (fn [dispatch get-state]
      (each [_ command (ipairs commands)]
        (when command
          (command dispatch get-state))))))

(fn persist-reviewed []
  (fn [dispatch get-state]
    (let [state (get-state)]
      (when (not (reviews.persist state.review_store state.review_scope
                                  state.entries))
        (dispatch {:type :review-persist-failed})))))

(fn warm-preview-cache []
  (fn [_dispatch get-state]
    (let [state (get-state)]
      (preview-warm.start state.preview_warm state.src_dir state.revision
                          state.entries))))

(fn sync-start []
  (fn [_dispatch get-state]
    (let [state (get-state)]
      (sync.request state.sync))))

(fn open-editor [config entry]
  (fn [_dispatch get-state]
    (editor.run config entry (. (get-state) :stty-state))))

(fn copy-path [path]
  (fn [dispatch _get-state]
    (dispatch {:type :copy-path-finished :path path :ok? (clipboard.copy path)})))

(fn refresh []
  (fn [dispatch get-state]
    (let [state (get-state)
          reviewed (reviews.paths state.entries)
          (entries err) (git.diff-entries state.revision)]
      (when (not err)
        (dispatch {:type :refresh-loaded :entries entries :reviewed reviewed})))))

{: batch
 : copy-path
 : none
 : open-editor
 : persist-reviewed
 : refresh
 : sync-start
 : warm-preview-cache}
