(local preview (require :preview.core))
(local preview-search (require :app.preview-search))
(local selection (require :app.selection))
(local line-selection (require :app.line-selection))
(local viewport (require :preview.viewport))
(local pane (require :tui.components.pane))
(local scroll-util (require :util.scroll))
(local symbols (require :tui.symbols))
(local theme (require :tui.theme))
(local tui (require :tui.core))
(local ansi (require :tui.ansi))
(local wrap (require :tui.wrap))
(local word-diff (require :preview.word-diff))

(fn scrolling? [state]
  (> (or state.preview_total 0) (or state.preview_rows 0)))

(fn split-halves [content]
  (let [available (math.max 0 (- content 1))
        old-w (math.floor (/ available 2))]
    (values old-w (- available old-w))))

(fn half-widths [state cols]
  (let [content (viewport.content-width state.split_ratio cols
                                        (scrolling? state))
        (old-w new-w) (split-halves content)]
    (values content old-w new-w)))

(fn max-raw-width [rows]
  (accumulate [w 0 _ row (ipairs rows)]
    (math.max w (tui.visible-length (or row.old ""))
              (tui.visible-length (or row.new "")))))

(fn full-row? [row]
  (or (= row.kind :filename) (= row.kind :rule)))

(fn change-role [row side]
  (if (= row.kind :hunk) :muted
      (let [value (. row side)]
        (if (and (= row.kind :change) value)
            (if (= side :old) :status-deleted :status-added)))))

(fn highlight-row? [state index]
  (and (= state.focus :right)
       (if (line-selection.active? state)
           (let [(lo hi) (line-selection.range state.preview_selection_anchor
                                               (or state.preview_cursor 1))]
             (and (>= index lo) (<= index hi)))
           (= index (or state.preview_cursor 1)))))

(fn styled [state text width selected?]
  (if selected? (theme.selected-row state.theme text width) text))

(fn highlighted [state highlight? text]
  (if (and highlight? (preview-search.has-query? state))
      (preview-search.highlight state text)
      text))

(fn half [state row side width x-scroll selected?]
  (let [role (change-role row side)
        raw (or (. row side) "")
        colored (if role (tui.color state.theme role raw) raw)
        searched (highlighted state (= side state.split_side) colored)
        windowed (pane.window-text searched width x-scroll)]
    (styled state windowed width selected?)))

(fn divider [state]
  (tui.color state.theme :muted symbols.line.vertical))

(fn full-width [state text content selected? ?color]
  (let [colored (if ?color (tui.color state.theme ?color text) text)
        searched (highlighted state true colored)
        windowed (pane.window-text searched content 0)]
    (styled state windowed content selected?)))

(fn rule-line [state old-w new-w]
  (tui.color state.theme :muted
             (.. (string.rep symbols.line.horizontal old-w)
                 symbols.line.join-down
                 (string.rep symbols.line.horizontal new-w))))

(fn compose-row [state row index old-w new-w content x-scroll]
  (let [selected? (highlight-row? state index)]
    (if (= row.kind :filename)
        (full-width state (or row.new row.old "") content selected?)
        (= row.kind :rule)
        (rule-line state old-w new-w)
        (.. (half state row :old old-w x-scroll
                  (and selected? (= state.split_side :old)))
            (divider state)
            (half state row :new new-w x-scroll
                  (and selected? (= state.split_side :new)))))))

(fn entry-rows [state ?selected]
  (let [selected (or ?selected (selection.selected-context state))]
    (preview.split-rows state selected.entry)))

(fn sync-search [state rows]
  (when (and (= state.focus :right) (preview-search.has-query? state)
             (not (= state.preview_search.matches_source rows)))
    (set state.preview_search.matches_source rows)
    (preview-search.rebuild state true)))

(fn visual-rows-for [row old-w new-w content]
  (if (full-row? row)
      (icollect [_ frag (ipairs (wrap.line (or row.old "") content))]
        {:kind row.kind :old frag :new frag})
      (let [olds (and row.old (wrap.line row.old old-w))
            news (and row.new (wrap.line row.new new-w))
            n (math.max 1 (length (or olds [])) (length (or news [])))]
        (fcollect [i 1 n]
          {:kind row.kind
           :old (and olds (. olds i))
           :new (and news (. news i))}))))

(fn wrap-rows [rows old-w new-w content]
  (let [display []
        source-map []]
    (each [index row (ipairs (or rows []))]
      (each [_ vrow (ipairs (visual-rows-for row old-w new-w content))]
        (table.insert display vrow)
        (table.insert source-map index)))
    (values display source-map)))

(fn store-widths [state content old-w new-w]
  (set state.split_widths {: content :old old-w :new new-w}))

(fn emphasize [theme-table raw ?span style-key]
  (if (and ?span (ansi.color?) (< ?span.from ?span.to))
      (.. (raw:sub 1 (- ?span.from 1)) (theme.style-for theme-table style-key)
          (raw:sub ?span.from (- ?span.to 1))
          (theme.style-for theme-table :emphasis-end) (raw:sub ?span.to))
      raw))

(fn display-row [theme-table row]
  (if (and (= row.kind :change) row.old row.new)
      (let [spans (word-diff.spans row.old row.new)]
        {:kind :change
         :old (emphasize theme-table row.old spans.old :emphasis-deleted)
         :new (emphasize theme-table row.new spans.new :emphasis-added)})
      row))

(fn emphasize-rows [theme-table rows]
  (icollect [_ row (ipairs (or rows []))]
    (display-row theme-table row)))

(fn prepare-truncated [state rows visible cols]
  (let [display (emphasize-rows state.theme rows)]
    (preview.apply-display-lines state display visible)
    (set state.split_rows display))
  (set state.split_source_map nil)
  (let [(content old-w new-w) (half-widths state cols)]
    (store-widths state content old-w new-w)
    (set state.preview_x_max_scroll
         (scroll-util.max-offset (max-raw-width rows) old-w))
    (set state.preview_x_scroll
         (math.min (or state.preview_x_scroll 0) state.preview_x_max_scroll))))

(fn prepare-wrapped [state rows visible cols]
  (let [emphasized (emphasize-rows state.theme rows)
        wide (viewport.content-width state.split_ratio cols false)
        (old-wide new-wide) (split-halves wide)
        (display-wide _) (wrap-rows emphasized old-wide new-wide wide)
        scroll? (scroll-util.scrolls? (length display-wide)
                                      (math.max 1 (or visible 1)))
        content (viewport.content-width state.split_ratio cols scroll?)
        (old-w new-w) (split-halves content)
        (display source-map) (wrap-rows emphasized old-w new-w content)]
    (preview.apply-display-lines state display visible)
    (set state.split_rows display)
    (set state.split_source_map source-map)
    (store-widths state content old-w new-w)
    (set state.preview_x_scroll 0)
    (set state.preview_x_max_scroll 0)))

(fn prepare [state visible cols ?selected]
  (let [rows (entry-rows state ?selected)]
    (set state.split_logical_rows rows)
    (if state.preview_wrap?
        (prepare-wrapped state rows visible cols)
        (prepare-truncated state rows visible cols))
    (sync-search state state.split_rows)))

(fn blank-divider [state old-w new-w]
  (.. (pane.blank old-w) (divider state) (pane.blank new-w)))

(fn body [state visible _cols]
  (let [rows (or state.split_rows [])
        widths (or state.split_widths {})
        content (or widths.content 0)
        old-w (or widths.old 0)
        new-w (or widths.new 0)
        x-scroll (or state.preview_x_scroll 0)
        offset (or state.preview_scroll 0)
        visible-rows (preview.visible-display-lines state rows visible)
        lines (icollect [i row (ipairs visible-rows)]
                (compose-row state row (+ offset i) old-w new-w content
                             x-scroll))]
    (for [_ (+ (length lines) 1) (math.max 1 (or visible 1))]
      (table.insert lines (blank-divider state old-w new-w)))
    (tui.lines lines (preview.scroll-info state) 0 0 nil [(+ old-w 1)])))

{: body : prepare : wrap-rows : split-halves}
