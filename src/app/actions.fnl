(local commands (require :app.commands))
(local action-plan (require :app.action-plan))
(local notice (require :app.notice))
(local preview (require :preview.core))
(local folder-preview (require :preview.folder))
(local review (require :app.review))
(local reviews (require :storage.reviews))
(local search (require :app.search))
(local pane-search (require :app.pane-search))
(local preview-search (require :app.preview-search))
(local line-selection (require :app.line-selection))
(local selection (require :app.selection))
(local tree (require :app.tree))

(import-macros {: set-fields} :state.macros)

(fn split-active? [state]
  (preview.split? state (selection.selected-entry state)))

(fn toggle-folder-reviewed [state row]
  (let [entries (or row.entries [])
        review? (review.toggle-all! entries)]
    (set state.notice (notice.reviewed-folder review? row.name))))

(fn refresh-hidden [state]
  (when state.hide_reviewed?
    (selection.invalidate-rows state)
    (selection.move state 0)))

(fn toggle-reviewed [state]
  (let [row (and (= state.view_mode :tree) (selection.selected-tree-row state))
        entry (selection.selected-entry state)]
    (if (and row (= row.type :folder))
        (toggle-folder-reviewed state row)
        entry
        (do
          (review.toggle-entry! entry)
          (set state.notice (notice.reviewed-entry entry)))))
  (refresh-hidden state)
  (commands.persist-reviewed))

(fn toggle-all-reviewed [state]
  (let [review? (review.toggle-all! state.entries)]
    (set state.notice (notice.reviewed-all review?))
    (refresh-hidden state)
    (commands.persist-reviewed)))

(fn cache-selected-preview [state]
  (let [entry (selection.selected-entry state)]
    (preview.lines state entry)
    (when state.split_mode?
      (preview.cache-split state entry)))
  state)

(fn apply-refresh [state entries reviewed diff-stats]
  (let [diff-focused? (= state.focus :right)
        prev-cursor state.preview_cursor
        prev-scroll state.preview_scroll]
    (set state.entries (reviews.apply entries reviewed))
    (selection.invalidate-rows state)
    (set state.diff_stats diff-stats)
    (set state.preview_cache {})
    (set state.preview_numbers_cache {})
    (set state.split_cache {})
    (set state.folder_preview_cache {})
    (line-selection.stop state)
    (preview.reset-scroll state)
    (selection.move state 0)
    (cache-selected-preview state)
    (if diff-focused?
        (preview.restore-cursor state prev-cursor prev-scroll)
        (preview.restore-scroll state prev-scroll))
    (commands.batch (commands.warm-preview-cache) (commands.persist-reviewed))))

(fn open-selected [state config]
  (let [target (action-plan.selected-target state.view_mode
                                            (selection.selected-tree-row state)
                                            (selection.selected-entry state))]
    (when target
      (if (= target.kind :folder)
          (commands.open-folder target.path)
          (commands.open-editor config (or target.entry {:path target.path}))))))

(fn current-target [state]
  (action-plan.selected-target state.view_mode
                               (selection.selected-tree-row state)
                               (selection.selected-entry state)))

(fn open-base-selected [state config]
  (let [target (current-target state)]
    (when (and target (= target.kind :file))
      (commands.open-base-editor config target))))

(fn copy-selected-path [state]
  (let [path (action-plan.copy-path (current-target state))]
    (when path
      (commands.copy-path path))))

(fn copy-full-selected-path [state]
  (let [path (action-plan.copy-full-path (current-target state) state.repo_root)]
    (when path
      (commands.copy-path path))))

(fn exit-line-selection [state]
  (when (line-selection.active? state)
    (line-selection.stop state)
    (set state.notice nil)))

(fn split-side-lines [logical-rows source-map display-len lo hi side]
  (let [seen {}
        out []]
    (for [i (math.max 1 lo) (math.min display-len hi)]
      (let [src (if source-map (. source-map i) i)
            row (and src (. logical-rows src))
            value (and row (. row side))]
        (when (and value (not (. seen src)))
          (tset seen src true)
          (table.insert out value))))
    out))

(fn split-selection [state]
  (let [(lo hi) (line-selection.range state.preview_selection_anchor
                                      (or state.preview_cursor 1))
        display (or state.split_rows [])
        logical (or state.split_logical_rows display)
        lines (split-side-lines logical state.split_source_map (length display)
                                lo hi state.split_side)]
    (values (table.concat lines "\n") (length lines))))

(fn preview-selection [state]
  (if (split-active? state)
      (split-selection state)
      (let [display (preview.display-lines state)
            source (preview.display-source state)
            source-map (preview.display-source-map state)
            anchor state.preview_selection_anchor
            cursor (or state.preview_cursor 1)]
        (values (line-selection.selected-text display anchor cursor source
                                              source-map)
                (line-selection.line-count display anchor cursor source-map)))))

(fn yank-preview [state]
  (let [(text count) (preview-selection state)]
    (exit-line-selection state)
    (when (> count 0)
      (commands.yank text count))))

(fn yank-preview-with-path [state]
  (let [(text count) (preview-selection state)
        path (action-plan.copy-path (current-target state))]
    (exit-line-selection state)
    (when (> count 0)
      (commands.yank-fenced (action-plan.fenced-snippet path text) path count))))

(fn copy-or-yank [state]
  (if (= state.focus :right)
      (yank-preview state)
      (copy-selected-path state)))

(fn copy-full-or-yank-with-path [state]
  (if (= state.focus :right)
      (yank-preview-with-path state)
      (copy-full-selected-path state)))

(fn toggle-line-selection [state]
  (when (= state.focus :right)
    (if (line-selection.active? state)
        (exit-line-selection state)
        (do
          (line-selection.start state)
          (set state.notice (notice.selecting-lines))))))

(fn move-split [state delta]
  (set state.split_ratio (action-plan.split-ratio state.split_ratio delta)))

(fn move-preview-cursor [state preview-fn]
  (let [changed? (preview-fn state)]
    (set state.skip_next_draw? (not changed?))
    changed?))

(fn navigate [state delta]
  (if (= state.focus :right)
      (move-preview-cursor state #(preview.move-cursor $1 delta))
      (selection.move state delta)))

(fn jump [state preview-fn select-fn]
  (if (= state.focus :right)
      (move-preview-cursor state preview-fn)
      (select-fn state)))

(fn focus-right [state side]
  (set state.focus :right)
  (set state.split_side side)
  (preview.focus-cursor state))

(fn focus-left [state]
  (exit-line-selection state)
  (set state.focus :left))

(fn exit-selection-or-clear-search [state]
  (if (line-selection.active? state) (exit-line-selection state)
      (pane-search.clear state)))

(fn back-to-files [state]
  (if (line-selection.active? state) (exit-line-selection state)
      (= state.focus :right) (focus-left state)
      (pane-search.clear state)))

(fn resync-split-search [state]
  (when (preview-search.has-query? state)
    (preview-search.rebuild state true)))

(fn cycle-split-focus [state first second]
  (if (not= state.focus :right)
      (do
        (focus-right state first)
        (resync-split-search state))
      (= state.split_side first)
      (do
        (set state.split_side second)
        (resync-split-search state))
      (focus-left state)))

(fn focus-step [state first second]
  (if (split-active? state) (cycle-split-focus state first second)
      (= state.focus :right) (focus-left state)
      (focus-right state state.split_side))
  (pane-search.refresh-status state))

(fn toggle-focus [state]
  (focus-step state :old :new))

(fn toggle-focus-back [state]
  (focus-step state :new :old))

(fn toggle-split [state]
  (set state.split_mode? (not state.split_mode?))
  (exit-line-selection state)
  (preview.reset-scroll state)
  (when (and state.split_mode? (= state.focus :right))
    (set state.split_side :old)))

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
  (exit-line-selection state)
  (set-fields state [:preview_wrap? (not state.preview_wrap?)]
              [:preview_x_scroll 0] [:preview_x_max_scroll 0]))

(fn toggle-show-numbers [state]
  (exit-line-selection state)
  (set-fields state [:show_numbers? (not state.show_numbers?)]
              [:preview_display_cache nil] [:preview_x_scroll 0]
              [:preview_x_max_scroll 0]))

(fn toggle-full-context [state]
  (when (selection.selected-entry state)
    (exit-line-selection state)
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

(fn toggle-hide-reviewed [state]
  (let [row (and (= state.view_mode :tree) (selection.selected-tree-row state))]
    (exit-line-selection state)
    (set state.hide_reviewed? (not state.hide_reviewed?))
    (selection.invalidate-rows state)
    (if row
        (settle-cursor state row)
        (selection.move state 0))))

(fn toggle-help [state]
  (set state.show_help? (not state.show_help?)))

(fn refresh-and-sync [state]
  (set state.show_sync_notice? true)
  (set state.notice (notice.syncing-remote))
  (commands.batch (commands.sync-start) (commands.refresh)))

(local handlers {:up #(navigate $1 -1)
                 :down #(navigate $1 1)
                 : toggle-focus
                 :focus-back toggle-focus-back
                 :open open-selected
                 :open-base open-base-selected
                 : toggle-reviewed
                 : toggle-all-reviewed
                 :preview-down scroll-preview-page-down
                 :preview-up scroll-preview-page-up
                 :preview-left #(scroll-horizontal $1 -8)
                 :preview-right #(scroll-horizontal $1 8)
                 :search pane-search.start
                 :search-next pane-search.next
                 :search-previous pane-search.previous
                 :clear-search exit-selection-or-clear-search
                 :back back-to-files
                 :toggle-line-selection toggle-line-selection
                 :top #(jump $1 preview.cursor-top selection.top)
                 :bottom #(jump $1 preview.cursor-bottom selection.bottom)
                 : toggle-wrap
                 : toggle-show-numbers
                 : toggle-split
                 : toggle-full-context
                 : toggle-tree
                 : toggle-hide-reviewed
                 : toggle-expand
                 :expand-all toggle-expand-all
                 : toggle-help
                 :refresh refresh-and-sync
                 :copy-path copy-or-yank
                 :copy-full-path copy-full-or-yank-with-path
                 :open-pr commands.open-linked-pr
                 :split-left #(move-split $1 -0.05)
                 :split-right #(move-split $1 0.05)})

(fn handle [state config msg-type]
  (let [handler (. handlers msg-type)]
    (when handler
      (handler state config))))

{: apply-refresh : cache-selected-preview : handle}
