(local git (require :git.core))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
(local selection (require :app.selection))
(local sync (require :git.sync))
(local theme (require :tui.theme))

(fn init [revision
          entries
          review-store
          review-scope
          src-dir
          ?diff-stats
          ?pr-url]
  (let [selected 1
        (old-ref new-ref) (git.comparison-sides revision)
        state {: revision
               :pr_url ?pr-url
               :src_dir src-dir
               :repo_root (git.repo-root)
               :revision_label (git.comparison-revision revision)
               :revision_old_label old-ref
               :revision_new_label new-ref
               : entries
               :diff_stats ?diff-stats
               :quit? false
               : selected
               :preview_scroll 0
               :preview_cursor 1
               :focus :left
               :preview_x_scroll 0
               :preview_x_max_scroll 0
               :files_x_scroll 0
               :files_x_max_scroll 0
               :preview_rows 1
               :preview_total 0
               :preview_selection_anchor nil
               :preview_wrap? true
               :show_numbers? false
               :show_blame? false
               :hide_reviewed? false
               :full_context? false
               :split_mode? true
               :split_side :old
               :split_cache {}
               :split_ratio 0.4
               :split_ratio_auto? true
               :view_mode :tree
               :tree_selected_row nil
               :expanded_folders {}
               :folder_preview_cache {}
               :theme theme.default
               :preview_cache {}
               :preview_numbers_cache {}
               :preview_line_refs_cache {}
               :preview_blame_cache {}
               :preview_warm (preview-warm.new-state)
               :review_store review-store
               :review_scope review-scope
               :search (search.new-state)
               :preview_search (search.new-state)
               :sync (sync.new-state revision)
               :show_sync_notice? false
               :show_help? false
               :skip_next_draw? false
               :force_next_draw? false
               :term_rows nil
               :term_cols nil
               :pending-key nil}]
    (selection.set-initial-tree-row state)
    state))

{: init}
