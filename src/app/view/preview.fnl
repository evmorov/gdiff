(local preview (require :preview.core))
(local selection (require :app.selection))
(local tui (require :tui.core))
(local viewport (require :preview.viewport))

(fn raw-lines [state selected-entry selected-row]
  (preview.selection-lines state selected-entry selected-row))

(fn lines-for-width [state lines visible cols]
  (viewport.lines-for-width state lines visible cols))

(fn set-scroll [state lines visible]
  (preview.apply-display-lines state lines visible))

(fn visible-lines [state lines visible]
  (preview.visible-display-lines state lines visible))

(fn has-vertical-scroll? [state]
  (not (= nil (preview.scroll-info state))))

(fn update-horizontal-scroll [state raw-lines cols]
  (preview.apply-horizontal-scroll-limit state raw-lines cols
                                         (has-vertical-scroll? state)))

(fn body [state visible cols]
  (let [selected-entry (selection.selected-entry state)
        selected-row (and (= state.view_mode :tree)
                          (selection.selected-tree-row state))
        raw (raw-lines state selected-entry selected-row)
        display (lines-for-width state raw visible cols)
        _ (set-scroll state display visible)
        visible-lines (visible-lines state display visible)
        _ (update-horizontal-scroll state raw cols)]
    (tui.lines visible-lines (preview.scroll-info state) state.preview_x_scroll
               state.preview_x_max_scroll)))

{: body}
