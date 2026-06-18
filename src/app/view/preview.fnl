(local preview (require :preview.core))
(local selection (require :app.selection))
(local tui (require :tui.core))

(fn raw-lines [state selected-entry selected-row]
  (preview.selection-lines state selected-entry selected-row))

(fn lines-for-width [state lines visible cols]
  (preview.display-lines-for-width state lines visible cols))

(fn set-scroll [state lines visible]
  (preview.apply-display-lines state lines visible))

(fn visible-lines [state lines visible]
  (preview.visible-display-lines state lines visible))

(fn has-vertical-scroll? [state]
  (not (= nil (preview.scroll-info state))))

(fn update-horizontal-scroll [state raw-lines cols]
  (preview.apply-horizontal-scroll-limit state raw-lines cols
                                         (has-vertical-scroll? state)))

(fn body [state visible cols ?selected]
  (let [selected (or ?selected (selection.selected-context state))
        raw (raw-lines state selected.entry selected.row)
        display (lines-for-width state raw visible cols)
        _ (set-scroll state display visible)
        visible-lines (visible-lines state display visible)
        _ (update-horizontal-scroll state raw cols)]
    (tui.lines visible-lines (preview.scroll-info state) state.preview_x_scroll
               state.preview_x_max_scroll)))

{: body}
