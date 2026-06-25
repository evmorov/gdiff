(local faith (require :faith))
(local app (require :app.core))
(local left-view (require :app.view.left))
(local preview-view (require :app.view.preview))
(local selection (require :app.selection))

(fn entry [status path]
  {: status :kind (status:sub 1 1) : path :reviewed false})

(fn state [entries]
  (let [state (app.new-state "HEAD" entries {:version 1 :reviews {}} "scope"
                             "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

(fn test-left-body-does-not-mutate-horizontal-scroll []
  (let [s (state [(entry "M" "a.rb")])]
    (set s.files_x_scroll 7)
    (set s.files_x_max_scroll 12)
    (left-view.body s 6)
    (faith.= 7 s.files_x_scroll)
    (faith.= 12 s.files_x_max_scroll)))

(fn test-left-prepare-resets-horizontal-scroll []
  (let [s (state [(entry "M" "a.rb")])]
    (set s.files_x_scroll 7)
    (set s.files_x_max_scroll 12)
    (left-view.prepare s)
    (faith.= 0 s.files_x_scroll)
    (faith.= 0 s.files_x_max_scroll)))

(fn test-preview-body-does-not-mutate-scroll-state []
  (let [s (state [(entry "M" "a.rb")])]
    (app.view s 10 80)
    (let [before {:scroll s.preview_scroll
                  :cursor s.preview_cursor
                  :x-scroll s.preview_x_scroll
                  :x-max-scroll s.preview_x_max_scroll
                  :total s.preview_total
                  :rows s.preview_rows}]
      (preview-view.body s 6)
      (faith.= before.scroll s.preview_scroll)
      (faith.= before.cursor s.preview_cursor)
      (faith.= before.x-scroll s.preview_x_scroll)
      (faith.= before.x-max-scroll s.preview_x_max_scroll)
      (faith.= before.total s.preview_total)
      (faith.= before.rows s.preview_rows))))

(fn selected-row [s]
  (set s.tree_selected_row (selection.selected-row-index s))
  (. (. (left-view.body s 6) :rows) 1))

(fn test-files-selection-has-background-only-when-pane-focused []
  (let [s (state [(entry "M" "a.rb")])]
    (set s.focus :left)
    (let [row (selected-row s)]
      (faith.is row.selected?)
      (faith.is (row.text:find "> " 1 true)))
    (set s.focus :right)
    (let [row (selected-row s)]
      (faith.= false row.selected?)
      (faith.is (row.text:find "> " 1 true)))))

{: test-left-body-does-not-mutate-horizontal-scroll
 : test-left-prepare-resets-horizontal-scroll
 : test-files-selection-has-background-only-when-pane-focused
 : test-preview-body-does-not-mutate-scroll-state}
