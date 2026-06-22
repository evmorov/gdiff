(local git (require :git.core))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
(local selection (require :app.selection))
(local sync (require :git.sync))
(local theme (require :tui.theme))

(fn init [revision entries review-store review-scope src-dir ?diff-stats]
  (let [selected 1
        state {: revision
               :src_dir src-dir
               :revision_label (git.comparison-revision revision)
               : entries
               :diff_stats ?diff-stats
               :quit? false
               : selected
               :preview_scroll 0
               :preview_x_scroll 0
               :preview_x_max_scroll 0
               :files_x_scroll 0
               :files_x_max_scroll 0
               :preview_rows 1
               :preview_total 0
               :preview_wrap? true
               :split_ratio 0.4
               :view_mode :tree
               :tree_selected_row nil
               :folder_preview_cache {}
               :theme theme.default
               :preview_cache {}
               :preview_context (git.preview-context)
               :preview_warm (preview-warm.new-state)
               :review_store review-store
               :review_scope review-scope
               :search (search.new-state)
               :sync (sync.new-state revision)
               :show_sync_notice? false
               :skip_next_draw? false
               :force_next_draw? false
               :term_rows nil
               :term_cols nil
               :pending-key nil}]
    (selection.set-initial-tree-row state)
    state))

{: init}
