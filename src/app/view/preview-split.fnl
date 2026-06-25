(local preview (require :preview.core))
(local selection (require :app.selection))
(local line-selection (require :app.line-selection))
(local viewport (require :preview.viewport))
(local pane (require :tui.components.pane))
(local scroll-util (require :util.scroll))
(local symbols (require :tui.symbols))
(local theme (require :tui.theme))
(local tui (require :tui.core))

(fn scrolling? [state]
  (> (or state.preview_total 0) (or state.preview_rows 0)))

(fn half-widths [state cols]
  (let [content (viewport.content-width state.split_ratio cols
                                        (scrolling? state))
        available (math.max 0 (- content 1))
        old-w (math.floor (/ available 2))]
    (values content old-w (- available old-w))))

(fn max-raw-width [rows]
  (accumulate [w 0 _ row (ipairs rows)]
    (math.max w (tui.visible-length (or row.old ""))
              (tui.visible-length (or row.new "")))))

(fn full-row? [row]
  (or (= row.kind :meta) (= row.kind :hunk)))

(fn change-role [row side]
  (let [value (. row side)]
    (if (and (= row.kind :change) value)
        (if (= side :old) :status-deleted :status-added)
        nil)))

(fn highlight-row? [state index]
  (and (= state.focus :right)
       (if (line-selection.active? state)
           (let [(lo hi) (line-selection.range state.preview_selection_anchor
                                               (or state.preview_cursor 1))]
             (and (>= index lo) (<= index hi)))
           (= index (or state.preview_cursor 1)))))

(fn styled [state text width selected?]
  (if selected? (theme.selected-row state.theme text width) text))

(fn half [state row side width x-scroll selected?]
  (let [windowed (pane.window-text (or (. row side) "") width x-scroll)
        role (change-role row side)
        colored (if role (tui.color state.theme role windowed) windowed)]
    (styled state colored width selected?)))

(fn divider [state]
  (tui.color state.theme :muted symbols.line.vertical))

(fn full-row [state row content selected?]
  (let [windowed (pane.window-text (or row.old "") content 0)]
    (styled state (tui.color state.theme :muted windowed) content selected?)))

(fn compose-row [state row index old-w new-w content x-scroll]
  (let [selected? (highlight-row? state index)]
    (if (full-row? row)
        (full-row state row content selected?)
        (.. (half state row :old old-w x-scroll
                  (and selected? (= state.split_side :old)))
            (divider state)
            (half state row :new new-w x-scroll
                  (and selected? (= state.split_side :new)))))))

(fn entry-rows [state ?selected]
  (let [selected (or ?selected (selection.selected-context state))]
    (preview.split-rows state selected.entry)))

(fn prepare [state visible cols ?selected]
  (let [rows (entry-rows state ?selected)
        (_content old-w _new-w) (do
                                  (preview.apply-display-lines state rows
                                                               visible)
                                  (half-widths state cols))]
    (set state.split_rows rows)
    (set state.preview_x_max_scroll
         (scroll-util.max-offset (max-raw-width rows) old-w))
    (set state.preview_x_scroll
         (math.min (or state.preview_x_scroll 0) state.preview_x_max_scroll))))

(fn body [state visible cols]
  (let [rows (or state.split_rows [])
        (content old-w new-w) (half-widths state cols)
        x-scroll (or state.preview_x_scroll 0)
        offset (or state.preview_scroll 0)
        visible-rows (preview.visible-display-lines state rows visible)
        lines (icollect [i row (ipairs visible-rows)]
                (compose-row state row (+ offset i) old-w new-w content
                             x-scroll))]
    (tui.lines lines (preview.scroll-info state) 0 0 nil)))

{: body : prepare}
