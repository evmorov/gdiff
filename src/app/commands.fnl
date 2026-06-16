(local clipboard (require :platform.clipboard))
(local editor (require :platform.editor))
(local git (require :git.core))
(local preview-warm (require :preview.warm))
(local reviews (require :storage.reviews))
(local sync (require :git.sync))

(import-macros {: defcommand} :app.macros)

(fn none [_dispatch _get-state]
  nil)

(fn batch [...]
  (let [commands [...]]
    (fn [dispatch get-state]
      (each [_ command (ipairs commands)]
        (when command
          (command dispatch get-state))))))

(defcommand persist-reviewed
  []
  [dispatch get-state]
  (let [state (get-state)]
    (when (not (reviews.persist state.review_store state.review_scope
                                state.entries))
      (dispatch {:type :review-persist-failed}))))

(defcommand warm-preview-cache
  []
  [_dispatch get-state]
  (let [state (get-state)]
    (preview-warm.start state.preview_warm state.src_dir state.revision
                        state.entries)))

(defcommand sync-start
  []
  [_dispatch get-state]
  (let [state (get-state)]
    (sync.request state.sync)))

(defcommand open-editor
  [config entry]
  [_dispatch get-state]
  (editor.run config entry (. (get-state) :stty-state)))

(defcommand copy-path
  [path]
  [dispatch _get-state]
  (dispatch {:type :copy-path-finished :path path :ok? (clipboard.copy path)}))

(defcommand refresh
  []
  [dispatch get-state]
  (let [state (get-state)
        reviewed (reviews.paths state.entries)
        (entries err) (git.diff-entries state.revision)]
    (when (not err)
      (dispatch {:type :refresh-loaded :entries entries :reviewed reviewed}))))

{: batch
 : copy-path
 : none
 : open-editor
 : persist-reviewed
 : refresh
 : sync-start
 : warm-preview-cache}
