(local faith (require :faith))
(local app (require :app.core))
(local left-view (require :app.view.left))
(local preview-view (require :app.view.preview))
(local selection (require :app.selection))
(local t (require :test-helper))

(fn entry [status path]
  {: status :kind (status:sub 1 1) : path :reviewed false})

(fn state [entries]
  (let [state (app.new-state "HEAD" entries {:version 1 :reviews {}} "scope"
                             "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

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

(fn test-loading-frame-body-does-not-mutate-state []
  (t.reset-workdir)
  (let [s (state [(entry "M" "a.rb")])]
    (set s.preview_focus (t.focus-state "focus"))
    (app.view s 10 80)
    (let [before {:scroll s.preview_scroll
                  :cursor s.preview_cursor
                  :total s.preview_total
                  :cache (t.count-pairs s.preview_cache)}]
      (preview-view.body s 6)
      (faith.= before.scroll s.preview_scroll)
      (faith.= before.cursor s.preview_cursor)
      (faith.= before.total s.preview_total)
      (faith.= 0 before.cache)
      (faith.= before.cache (t.count-pairs s.preview_cache)))))

(fn selected-row [s]
  (set s.tree_selected_row (selection.selected-row-index s))
  (. (. (left-view.body s 6) :rows) 1))

(fn test-files-selection-dims-background-when-pane-unfocused []
  (let [s (state [(entry "M" "a.rb")])]
    (set s.focus :left)
    (let [row (selected-row s)]
      (faith.is row.selected?)
      (faith.= false row.inactive?)
      (faith.is (row.text:find "> " 1 true)))
    (set s.focus :right)
    (let [row (selected-row s)]
      (faith.= false row.selected?)
      (faith.is row.inactive?)
      (faith.is (row.text:find "> " 1 true)))))

{: test-files-selection-dims-background-when-pane-unfocused
 : test-loading-frame-body-does-not-mutate-state
 : test-preview-body-does-not-mutate-scroll-state}
