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
(local wrap (require :tui.wrap))
(local word-diff (require :preview.word-diff))

(fn split-halves [content]
  (let [available (math.max 0 (- content 1))
        old-w (math.floor (/ available 2))]
    (values old-w (- available old-w))))

(fn number-width [rows key]
  (accumulate [w 0 _ row (ipairs (or rows []))]
    (math.max w (if (. row key) (length (tostring (. row key))) 0))))

(fn number-widths [state rows]
  (if state.show_numbers?
      (values (number-width rows :old-no) (number-width rows :new-no))
      (values 0 0)))

(fn gutter-cols [width]
  (if (> width 0) (+ width 1) 0))

(fn number-text [?no width]
  (let [text (if ?no (tostring ?no) "")]
    (.. (string.rep " " (math.max 0 (- width (length text)))) text)))

(fn side-gutter [state width ?no]
  (if (> (or width 0) 0)
      (tui.color state.theme :muted (.. (number-text ?no width) " "))
      ""))

(fn layout-widths [state content rows]
  (let [(old-no-w new-no-w) (number-widths state rows)
        old-gc (gutter-cols old-no-w)
        new-gc (gutter-cols new-no-w)
        (old-w new-w) (split-halves (math.max 0 (- content old-gc new-gc)))]
    {: content :old old-w :new new-w : old-no-w : new-no-w : old-gc : new-gc}))

(fn max-raw-width [rows]
  (accumulate [w 0 _ row (ipairs rows)]
    (math.max w (tui.visible-length (or row.old ""))
              (tui.visible-length (or row.new "")))))

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

(fn header-half [state text width selected? ?color]
  (let [colored (if ?color (tui.color state.theme ?color text) text)
        windowed (pane.window-text colored width 0)]
    (styled state windowed width selected?)))

(fn compose-row [state row index widths x-scroll]
  (let [old-w widths.old
        new-w widths.new
        selected? (highlight-row? state index)
        old-sel? (and selected? (= state.split_side :old))
        new-sel? (and selected? (= state.split_side :new))
        old-gutter (side-gutter state widths.old-no-w row.old-no)
        new-gutter (side-gutter state widths.new-no-w row.new-no)]
    (if (or (= row.kind :filename) (= row.kind :rule))
        (let [?color (when (= row.kind :rule) :muted)]
          (.. old-gutter (header-half state (or row.old "") old-w old-sel?
                                      ?color)
              (divider state) new-gutter
              (header-half state (or row.new "") new-w new-sel? ?color)))
        (.. old-gutter (half state row :old old-w x-scroll old-sel?)
            (divider state) new-gutter
            (half state row :new new-w x-scroll new-sel?)))))

(fn entry-rows [state ?selected]
  (let [selected (or ?selected (selection.selected-context state))]
    (preview.split-rows state selected.entry)))

(fn sync-search [state rows]
  (when (and (= state.focus :right) (preview-search.has-query? state)
             (not (= state.preview_search.matches_source rows)))
    (set state.preview_search.matches_source rows)
    (preview-search.rebuild state true)))

(fn visual-rows-for [row old-w new-w]
  (let [olds (and row.old (wrap.line row.old old-w))
        news (and row.new (wrap.line row.new new-w))
        n (math.max 1 (length (or olds [])) (length (or news [])))]
    (fcollect [i 1 n]
      {:kind row.kind
       :old (and olds (. olds i))
       :new (and news (. news i))
       :old-no (when (= i 1) row.old-no)
       :new-no (when (= i 1) row.new-no)})))

(fn wrap-rows [rows old-w new-w _content]
  (let [display []
        source-map []]
    (each [index row (ipairs (or rows []))]
      (each [_ vrow (ipairs (visual-rows-for row old-w new-w))]
        (table.insert display vrow)
        (table.insert source-map index)))
    (values display source-map)))

(fn underline [text]
  (string.rep symbols.line.horizontal (tui.visible-length (or text ""))))

(fn display-row [theme-table row]
  (if (and (= row.kind :change) row.old row.new row.emphasize?)
      (let [spans (or row.spans (word-diff.spans row.old row.new))]
        {:kind :change
         :old (word-diff.emphasize theme-table row.old spans.old
                                   :emphasis-deleted)
         :new (word-diff.emphasize theme-table row.new spans.new
                                   :emphasis-added)
         :old-no row.old-no
         :new-no row.new-no})
      (= row.kind :rule)
      {:kind :rule :old (underline row.old) :new (underline row.new)}
      row))

(fn emphasize-rows [theme-table rows]
  (icollect [_ row (ipairs (or rows []))]
    (display-row theme-table row)))

(fn prepare-truncated [state rows visible cols]
  (let [display (emphasize-rows state.theme rows)
        scroll? (scroll-util.scrolls? (length display)
                                      (math.max 1 (or visible 1)))
        content (viewport.content-width state.split_ratio cols scroll?)
        widths (layout-widths state content rows)
        x-max (scroll-util.max-offset (max-raw-width rows) widths.old)]
    {: display :source-map nil : widths :x-max-scroll x-max :wrap? false}))

(fn prepare-wrapped [state rows visible cols]
  (let [emphasized (emphasize-rows state.theme rows)
        wide (viewport.content-width state.split_ratio cols false)
        wide-widths (layout-widths state wide rows)
        (display-wide _) (wrap-rows emphasized wide-widths.old wide-widths.new
                                    wide)
        scroll? (scroll-util.scrolls? (length display-wide)
                                      (math.max 1 (or visible 1)))
        content (viewport.content-width state.split_ratio cols scroll?)
        widths (layout-widths state content rows)
        (display source-map) (wrap-rows emphasized widths.old widths.new
                                        content)]
    {: display : source-map : widths :x-max-scroll 0 :wrap? true}))

(fn compute-layout [state rows visible cols]
  (if state.preview_wrap?
      (prepare-wrapped state rows visible cols)
      (prepare-truncated state rows visible cols)))

(fn cached-layout? [state rows visible cols]
  (let [cache state.split_display_cache]
    (and cache (= cache.rows rows) (= cache.visible visible)
         (= cache.cols cols) (= cache.split-ratio state.split_ratio)
         (= cache.wrap? state.preview_wrap?)
         (= cache.numbers? (and state.show_numbers? true)))))

(fn apply-layout [state layout visible]
  (set state.split_rows layout.display)
  (set state.split_source_map layout.source-map)
  (set state.split_widths layout.widths)
  (preview.apply-display-lines state layout.display visible)
  (if layout.wrap?
      (do
        (set state.preview_x_scroll 0)
        (set state.preview_x_max_scroll 0))
      (do
        (set state.preview_x_max_scroll layout.x-max-scroll)
        (set state.preview_x_scroll
             (math.min (or state.preview_x_scroll 0) layout.x-max-scroll)))))

(fn prepare [state visible cols ?selected]
  (let [rows (entry-rows state ?selected)]
    (set state.split_logical_rows rows)
    (let [layout (if (cached-layout? state rows visible cols)
                     state.split_display_cache.layout
                     (let [computed (compute-layout state rows visible cols)]
                       (set state.split_display_cache
                            {: rows
                             : visible
                             : cols
                             :split-ratio state.split_ratio
                             :wrap? state.preview_wrap?
                             :numbers? (and state.show_numbers? true)
                             :layout computed})
                       computed))]
      (apply-layout state layout visible)
      (sync-search state state.split_rows))))

(fn blank-divider [state widths]
  (.. (side-gutter state widths.old-no-w nil) (pane.blank widths.old)
      (divider state) (side-gutter state widths.new-no-w nil)
      (pane.blank widths.new)))

(fn body [state visible _cols]
  (let [rows (or state.split_rows [])
        widths (or state.split_widths {})
        old-w (or widths.old 0)
        old-gc (or widths.old-gc 0)
        x-scroll (or state.preview_x_scroll 0)
        offset (or state.preview_scroll 0)
        visible-rows (preview.visible-display-lines state rows visible)
        lines (icollect [i row (ipairs visible-rows)]
                (compose-row state row (+ offset i) widths x-scroll))]
    (for [_ (+ (length lines) 1) (math.max 1 (or visible 1))]
      (table.insert lines (blank-divider state widths)))
    (tui.lines lines (preview.scroll-info state) 0 0 nil [(+ old-gc old-w 1)])))

{: body : prepare : wrap-rows : split-halves}
