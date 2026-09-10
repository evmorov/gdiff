(local line-selection (require :app.line-selection))
(local preview (require :preview.core))
(local selection (require :app.selection))

(fn split-active? [state]
  (preview.split? state (selection.selected-entry state)))

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

(fn split-text [state]
  (let [(lo hi) (line-selection.range state.preview_selection_anchor
                                      (or state.preview_cursor 1))
        display (or state.split_rows [])
        logical (or state.split_logical_rows display)
        lines (split-side-lines logical state.split_source_map (length display)
                                lo hi state.split_side)]
    (values (table.concat lines "\n") (length lines))))

(fn unified-text [state]
  (let [display (preview.display-lines state)
        source (preview.display-source state)
        source-map (preview.display-source-map state)
        anchor state.preview_selection_anchor
        cursor (or state.preview_cursor 1)]
    (values (line-selection.selected-text display anchor cursor source
                                          source-map)
            (line-selection.line-count display anchor cursor source-map))))

(fn text [state]
  "The selected preview text and its line count, from whichever view is shown."
  (if (split-active? state)
      (split-text state)
      (unified-text state)))

(fn single-source-index [display anchor cursor source-map]
  "The source line index under the cursor, or nil when the selection spans
  more than one source line."
  (when (= 1 (line-selection.line-count display anchor cursor source-map))
    (if source-map (. source-map cursor) cursor)))

(fn split-line-target [state]
  (let [display (or state.split_rows [])
        logical (or state.split_logical_rows display)
        cursor (or state.preview_cursor 1)
        index (single-source-index display state.preview_selection_anchor
                                   cursor state.split_source_map)
        row (and index (. logical index))
        side state.split_side
        no (and row (if (= side :old) row.old-no row.new-no))]
    (when no {: side : no :entry (selection.selected-entry state)})))

(fn unified-line-target [state]
  (let [entry (selection.selected-entry state)
        display (preview.display-lines state)
        cursor (or state.preview_cursor 1)
        index (single-source-index display state.preview_selection_anchor
                                   cursor (preview.display-source-map state))
        refs (and index (preview.line-refs state entry))
        ref (and refs (. refs index))]
    (when ref {:side ref.side :no ref.no : entry})))

(fn line-target [state]
  "The entry, side, and line number under the preview cursor, or nil when the
  cursor covers more than one source line."
  (if (split-active? state)
      (split-line-target state)
      (unified-line-target state)))

{: line-target : text}
