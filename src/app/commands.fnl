(local browser (require :platform.browser))
(local clipboard (require :platform.clipboard))
(local editor (require :platform.editor))
(local git (require :git.core))
(local messages (require :app.messages))
(local preview-warm (require :preview.warm))
(local reviews (require :storage.reviews))
(local sync (require :git.sync))
(local sys (require :platform.core))

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
      (dispatch (messages.review-persist-failed)))))

(defcommand warm-preview-cache
  []
  [_dispatch get-state]
  (let [state (get-state)]
    (preview-warm.start state.preview_warm state.src_dir state.revision
                        (preview-warm.missing-entries state.revision
                                                      (preview-warm.side-priority-entries state.entries)
                                                      state.preview_cache))))

(defcommand sync-start
  []
  [_dispatch get-state]
  (let [state (get-state)]
    (sync.start state.sync)))

(defcommand open-editor
  [config entry]
  [dispatch get-state]
  (let [exists? (sys.file-exists? entry.path)]
    (when exists?
      (editor.run config entry (. (get-state) :stty-state)))
    (dispatch (messages.open-target-finished :file entry.path exists?))))

(defcommand open-folder
  [path]
  [dispatch _get-state]
  (let [exists? (sys.dir-exists? path)]
    (when exists?
      (browser.open path))
    (dispatch (messages.open-target-finished :folder path exists?))))

(defcommand copy-path
  [path]
  [dispatch _get-state]
  (dispatch (messages.copy-path-finished path (clipboard.copy path))))

(defcommand yank
  [text count]
  [dispatch _get-state]
  (dispatch (messages.yank-finished count (clipboard.copy text))))

(defcommand open-linked-pr
  []
  [dispatch get-state]
  (let [state (get-state)
        (url err) (git.linked-pr-url state.revision)]
    (if url
        (do
          (browser.open url)
          (dispatch (messages.open-pr-finished url nil true)))
        (dispatch (messages.open-pr-finished nil err false)))))

(defcommand refresh
  []
  [dispatch get-state]
  (let [state (get-state)
        reviewed (reviews.paths state.entries)
        (entries err) (git.diff-entries state.revision)
        (diff-stats _stats-err) (if (not err)
                                    (git.diff-stats state.revision)
                                    (values nil nil))]
    (when (not err)
      (dispatch (messages.refresh-loaded entries reviewed diff-stats)))))

{: batch
 : copy-path
 : none
 : open-editor
 : open-folder
 : open-linked-pr
 : persist-reviewed
 : refresh
 : sync-start
 : warm-preview-cache
 : yank}
