(local preview (require :preview.core))
(local preview-anchor (require :preview.anchor))
(local preview-search (require :app.preview-search))
(local selection (require :app.selection))
(local line-selection (require :app.line-selection))
(local tui (require :tui.core))

(fn raw-lines [state selected-entry selected-row]
  (preview.selection-lines state selected-entry selected-row))

(fn lines-for-width [state lines numbers visible cols]
  (preview.display-lines-for-width state lines numbers visible cols))

(fn set-scroll [state lines visible]
  (preview.apply-display-lines state lines visible))

(fn visible-lines [state lines visible]
  (preview.visible-display-lines state lines visible))

(fn has-vertical-scroll? [state]
  (not (= nil (preview.scroll-info state))))

(fn update-horizontal-scroll [state raw-lines cols]
  (preview.apply-horizontal-scroll-limit state raw-lines cols
                                         (has-vertical-scroll? state)))

(fn visible-row [state line]
  (- line (or state.preview_scroll 0)))

(fn cursor-highlight [state visible-lines]
  (when (= state.focus :right)
    (let [visible (length visible-lines)
          cursor (or state.preview_cursor 1)]
      (if (line-selection.active? state)
          (let [(lo hi) (line-selection.range state.preview_selection_anchor
                                              cursor)
                rows {}]
            (for [line lo hi]
              (let [row (visible-row state line)]
                (when (and (>= row 1) (<= row visible))
                  (tset rows row true))))
            (when (next rows) rows))
          (let [row (visible-row state cursor)]
            (when (and (>= row 1) (<= row visible))
              row))))))

(fn search-highlight [state lines]
  (if (preview-search.has-query? state)
      (icollect [_ line (ipairs lines)]
        (preview-search.highlight state line))
      lines))

(fn sync-search [state display]
  (when (and (= state.focus :right) (preview-search.has-query? state)
             (not (= state.preview_search.matches_source display)))
    (set state.preview_search.matches_source display)
    (preview-search.rebuild state true)))

(fn prepare [state visible cols ?selected]
  (let [selected (or ?selected (selection.selected-context state))
        (raw numbers) (raw-lines state selected.entry selected.row)
        display (lines-for-width state raw numbers visible cols)]
    (sync-search state display)
    (set-scroll state display visible)
    (preview-anchor.restore-unified state selected.entry)
    (update-horizontal-scroll state raw cols)))

(fn body [state visible]
  (let [display (preview.display-lines state)
        gutters (preview.display-gutters state)
        visible-lines (visible-lines state display visible)
        visible-gutters (preview.visible-display-gutters state gutters visible)]
    (tui.lines (search-highlight state visible-lines)
               (preview.scroll-info state) state.preview_x_scroll
               state.preview_x_max_scroll (cursor-highlight state visible-lines)
               nil visible-gutters)))

{: body : prepare}
