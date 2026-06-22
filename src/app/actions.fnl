(local commands (require :app.commands))
(local action-plan (require :app.action-plan))
(local notice (require :app.notice))
(local preview (require :preview.core))
(local folder-preview (require :preview.folder))
(local review (require :app.review))
(local reviews (require :storage.reviews))
(local search (require :app.search))
(local selection (require :app.selection))
(local tree (require :app.tree))

(import-macros {: set-fields} :state.macros)

(fn toggle-folder-reviewed [state row]
  (let [entries (or row.entries [])
        review? (review.toggle-all! entries)]
    (set state.notice (notice.reviewed-folder review? row.name))))

(fn toggle-reviewed [state]
  (let [row (and (= state.view_mode :tree) (selection.selected-tree-row state))
        entry (selection.selected-entry state)]
    (if (and row (= row.type :folder))
        (toggle-folder-reviewed state row)
        entry
        (do
          (review.toggle-entry! entry)
          (set state.notice (notice.reviewed-entry entry)))))
  (commands.persist-reviewed))

(fn toggle-all-reviewed [state]
  (let [review? (review.toggle-all! state.entries)]
    (set state.notice (notice.reviewed-all review?))
    (commands.persist-reviewed)))

(fn cache-selected-preview [state]
  (preview.lines state (selection.selected-entry state))
  state)

(fn apply-refresh [state entries reviewed diff-stats]
  (set state.entries (reviews.apply entries reviewed))
  (selection.invalidate-rows state)
  (set state.diff_stats diff-stats)
  (set state.folder_preview_cache {})
  (preview.reset-scroll state)
  (selection.move state 0)
  (cache-selected-preview state)
  (commands.batch (commands.warm-preview-cache) (commands.persist-reviewed)))

(fn open-selected [state config]
  (let [target (action-plan.selected-target state.view_mode
                                            (selection.selected-tree-row state)
                                            (selection.selected-entry state))]
    (when target
      (if (= target.kind :folder)
          (commands.open-folder target.path)
          (commands.open-editor config (or target.entry {:path target.path}))))))

(fn copy-selected-path [state]
  (let [target (action-plan.selected-target state.view_mode
                                            (selection.selected-tree-row state)
                                            (selection.selected-entry state))
        path (action-plan.copy-path target)]
    (when path
      (commands.copy-path path))))

(fn move-split [state delta]
  (set state.split_ratio (action-plan.split-ratio state.split_ratio delta)))

(fn scroll-horizontal [state delta]
  (let [changed? (preview.scroll-horizontal state delta)]
    (set state.skip_next_draw? (not changed?))
    changed?))

(fn scroll-preview [state entry delta]
  (let [changed? (preview.scroll state entry delta)]
    (set state.skip_next_draw? (not changed?))
    changed?))

(fn scroll-preview-page-down [state]
  (scroll-preview state (selection.selected-entry state)
                  (preview.page-step state)))

(fn scroll-preview-page-up [state]
  (scroll-preview state (selection.selected-entry state)
                  (- (preview.page-step state))))

(fn toggle-wrap [state]
  (set-fields state [:preview_wrap? (not state.preview_wrap?)]
              [:preview_x_scroll 0] [:preview_x_max_scroll 0]))

(fn toggle-full-context [state]
  (when (selection.selected-entry state)
    (set state.full_context? (not state.full_context?))
    (preview.reset-scroll state)))

(fn toggle-tree [state]
  (selection.toggle-mode state)
  (when (search.has-query? state)
    (search.rebuild state true)))

(fn row-folder-path [row]
  (case row.type
    :folder row.path
    :file row.folder-path))

(fn set-folder-expanded [state path expand?]
  (if expand?
      (tset state.expanded_folders path
            (folder-preview.folder-entries state path))
      (tset state.expanded_folders path nil)))

(fn settled-row-index [state row]
  (if (not row) state.tree_selected_row
      (= row.type :folder) (selection.folder-row-index state row.path)
      row.unchanged (or (selection.file-row-index-by-path state row.path)
                        (selection.last-file-row-index state row.folder-path)
                        (selection.folder-row-index state row.folder-path))
      (selection.entry-row-index state row.entry-index)))

(fn settle-cursor [state row]
  (selection.set-tree-row state
                          (or (settled-row-index state row)
                              state.tree_selected_row)))

(fn toggle-expand [state]
  (when (= state.view_mode :tree)
    (let [row (selection.selected-tree-row state)
          path (and row (row-folder-path row))]
      (when (and path (< 0 (length path)))
        (set-folder-expanded state path (= nil (. state.expanded_folders path)))
        (selection.invalidate-rows state)
        (settle-cursor state row)
        (when (search.has-query? state)
          (search.rebuild state true))))))

(fn nested-changed-folders [state]
  (icollect [_ row (ipairs (tree.rows state.entries {}))]
    (when (and (= row.type :folder) (< 0 row.depth)) row.path)))

(fn all-expanded? [state paths]
  (accumulate [all? true _ path (ipairs paths)]
    (and all? (not (= nil (. state.expanded_folders path))))))

(fn toggle-expand-all [state]
  (when (= state.view_mode :tree)
    (let [paths (nested-changed-folders state)]
      (when (< 0 (length paths))
        (let [row (selection.selected-tree-row state)
              expand? (not (all-expanded? state paths))]
          (each [_ path (ipairs paths)]
            (set-folder-expanded state path expand?))
          (selection.invalidate-rows state)
          (settle-cursor state row)
          (when (search.has-query? state)
            (search.rebuild state true)))))))

(fn toggle-help [state]
  (set state.show_help? (not state.show_help?)))

(fn refresh-and-sync [state]
  (set state.show_sync_notice? true)
  (set state.notice (notice.syncing-remote))
  (commands.batch (commands.sync-start) (commands.refresh)))

(local handlers {:up #(selection.move $1 -1)
                 :down #(selection.move $1 1)
                 :open open-selected
                 : toggle-reviewed
                 : toggle-all-reviewed
                 :preview-down scroll-preview-page-down
                 :preview-up scroll-preview-page-up
                 :preview-left #(scroll-horizontal $1 -8)
                 :preview-right #(scroll-horizontal $1 8)
                 :search search.start
                 :search-next search.next
                 :search-previous search.previous
                 :clear-search search.clear
                 :top selection.top
                 :bottom selection.bottom
                 : toggle-wrap
                 : toggle-full-context
                 : toggle-tree
                 : toggle-expand
                 :expand-all toggle-expand-all
                 : toggle-help
                 :refresh refresh-and-sync
                 :copy-path copy-selected-path
                 :open-pr commands.open-linked-pr
                 :split-left #(move-split $1 -0.05)
                 :split-right #(move-split $1 0.05)})

(fn handle [state config msg-type]
  (let [handler (. handlers msg-type)]
    (when handler
      (handler state config))))

{: apply-refresh : cache-selected-preview : handle}
