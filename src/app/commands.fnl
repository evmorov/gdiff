(local action-plan (require :app.action-plan))
(local browser (require :platform.browser))
(local clipboard (require :platform.clipboard))
(local editor (require :platform.editor))
(local git (require :git.core))
(local messages (require :app.messages))
(local pr-refresh (require :git.pr-refresh))
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
                                                      state.preview_cache)
                        state.revision_old_label state.revision_new_label)))

(defcommand sync-start
  []
  [_dispatch get-state]
  (let [state (get-state)]
    (sync.start state.sync)))

(defcommand pr-refresh-start
  []
  [_dispatch get-state]
  (let [state (get-state)]
    (pr-refresh.start state.pr_refresh)))

(defcommand open-editor
  [config entry]
  [dispatch get-state]
  (let [path (or entry.new_file entry.path)
        exists? (sys.file-exists? path)]
    (when exists?
      (editor.run config {: path} (. (get-state) :stty-state)))
    (dispatch (messages.open-target-finished :file path exists?))))

(defcommand open-base-editor
  [config target]
  [dispatch get-state]
  (let [state (get-state)
        ref (git.diff-base-ref state.revision)
        path (action-plan.base-source-path target)
        (temp err) (git.materialize-base ref path)]
    (when temp
      (editor.run config {:path temp} state.stty-state))
    (dispatch (messages.open-base-finished ref path (not err) err))))

(defcommand open-head-editor
  [config path]
  [dispatch get-state]
  (let [state (get-state)
        ref state.revision_new_label
        (temp err) (git.materialize-base ref path)]
    (when temp
      (editor.run config {:path temp} state.stty-state))
    (dispatch (messages.open-base-finished ref path (not err) err))))

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

(defcommand yank-fenced
  [text path count]
  [dispatch _get-state]
  (dispatch (messages.yank-fenced-finished path count (clipboard.copy text))))

(defcommand open-linked-pr
  []
  [dispatch get-state]
  (let [state (get-state)
        (url err) (if state.pr_url
                      (values state.pr_url nil)
                      (git.linked-pr-url state.revision))]
    (if url
        (do
          (browser.open url)
          (dispatch (messages.open-pr-finished url nil true)))
        (dispatch (messages.open-pr-finished nil err false)))))

(defcommand open-line-commit
  [target]
  [dispatch get-state]
  (let [state (get-state)
        (sha err) (git.blame-commit state.revision target.entry target.side
                                    target.no)
        (url url-err) (if sha (git.commit-url sha) (values nil err))]
    (if url
        (do
          (browser.open url)
          (dispatch (messages.open-commit-finished url nil true)))
        (dispatch (messages.open-commit-finished nil (or url-err err) false)))))

(defcommand refresh
  [?revision]
  [dispatch get-state]
  (let [state (get-state)
        revision (or ?revision state.revision)
        reviewed (reviews.paths state.entries)
        (entries err) (git.diff-entries revision)
        (diff-stats _stats-err) (if (not err)
                                    (git.diff-stats revision)
                                    (values nil nil))]
    (when (not err)
      (dispatch (messages.refresh-loaded entries reviewed diff-stats revision)))))

{: batch
 : copy-path
 : none
 : open-base-editor
 : open-editor
 : open-folder
 : open-head-editor
 : open-line-commit
 : open-linked-pr
 : persist-reviewed
 : pr-refresh-start
 : refresh
 : sync-start
 : warm-preview-cache
 : yank
 : yank-fenced}
