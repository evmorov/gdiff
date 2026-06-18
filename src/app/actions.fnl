(local commands (require :app.commands))
(local preview (require :preview.core))
(local review (require :app.review))
(local reviews (require :storage.reviews))
(local search (require :app.search))
(local selection (require :app.selection))
(local math-util (require :util.math))

(import-macros {: set-fields} :state.macros)

(fn move-selection [state delta]
  (selection.move state delta))

(fn set-notice [state action path]
  (set state.notice (.. action ": " path)))

(fn reviewed-action [entry]
  (if entry.reviewed "Marked reviewed" "Unmarked reviewed"))

(fn toggle-folder-reviewed [state row]
  (let [entries (or row.entries [])
        review? (review.toggle-all! entries)]
    (set-notice state (if review?
                          "Marked folder reviewed"
                          "Unmarked folder reviewed")
                row.name)))

(fn toggle-reviewed [state]
  (let [row (and (= state.view_mode :tree) (selection.selected-tree-row state))
        entry (selection.selected-entry state)]
    (if (and row (= row.type :folder))
        (toggle-folder-reviewed state row)
        entry
        (do
          (review.toggle-entry! entry)
          (set-notice state (reviewed-action entry) entry.path))))
  (commands.persist-reviewed))

(fn toggle-all-reviewed [state]
  (let [review? (review.toggle-all! state.entries)]
    (set state.notice (if review?
                          "Marked all reviewed"
                          "Unmarked all reviewed"))
    (commands.persist-reviewed)))

(fn cache-selected-preview [state]
  (preview.lines state (selection.selected-entry state))
  state)

(fn apply-refresh [state entries reviewed diff-stats]
  (set state.entries (reviews.apply entries reviewed))
  (set state.diff_stats diff-stats)
  (set state.folder_preview_cache {})
  (preview.reset-scroll state)
  (move-selection state 0)
  (cache-selected-preview state)
  (commands.batch (commands.warm-preview-cache) (commands.persist-reviewed)))

(fn open-selected [state config]
  (let [row (and (= state.view_mode :tree) (selection.selected-tree-row state))
        entry (selection.selected-entry state)]
    (if (and row (= row.type :folder))
        (do
          (set-notice state "Opening" row.path)
          (commands.open-folder row.path))
        entry
        (do
          (set-notice state "Opening" entry.path)
          (commands.open-editor config entry)))))

(fn copy-selected-path [state]
  (let [row (and (= state.view_mode :tree) (selection.selected-tree-row state))
        entry (selection.selected-entry state)
        path (if (and row (= row.type :folder))
                 (.. row.path "/")
                 (and entry entry.path))]
    (when path
      (commands.copy-path path))))

(fn move-split [state delta]
  (set state.split_ratio (math-util.clamp (+ (or state.split_ratio 0.4) delta)
                                          0.1 0.9)))

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

(fn toggle-tree [state]
  (selection.toggle-mode state)
  (when (search.has-query? state)
    (search.rebuild state true)))

(fn refresh-and-sync [state]
  (set state.show_sync_notice? true)
  (set state.notice "Syncing remote...")
  (commands.batch (commands.sync-start) (commands.refresh)))

(local handlers {:up #(move-selection $1 -1)
                 :down #(move-selection $1 1)
                 :open open-selected
                 :toggle-reviewed toggle-reviewed
                 :toggle-all-reviewed toggle-all-reviewed
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
                 :toggle-wrap toggle-wrap
                 :toggle-tree toggle-tree
                 :refresh refresh-and-sync
                 :copy-path copy-selected-path
                 :open-pr commands.open-linked-pr
                 :split-left #(move-split $1 -0.05)
                 :split-right #(move-split $1 0.05)})

(fn handle [state config msg-type]
  (let [handler (. handlers msg-type)]
    (when handler
      (handler state config))))

{: apply-refresh : cache-selected-preview : handle : handlers : set-notice}
