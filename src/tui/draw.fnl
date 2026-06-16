(local ansi (require :tui.ansi))
(local nodes (require :tui.nodes))
(local terminal (require :tui.terminal))
(local theme-store (require :tui.theme))

(fn write-row [theme line selected? width ?newline]
  (io.write (if selected? (theme-store.selected-row theme line width) line))
  (when ?newline
    (io.write ansi.nl)))

(fn draw-header [theme view cols]
  (io.write ansi.esc "[2J" ansi.esc "[H")
  (io.write (ansi.truncate view.header cols) ansi.nl)
  (io.write (theme-store.color theme :muted (string.rep "-" cols)) ansi.nl))

(fn draw-rows [theme rows cols]
  (each [_ row (ipairs rows)]
    (write-row theme (ansi.truncate row.text cols) row.selected? cols true)))

(fn draw-lines [lines cols]
  (each [_ line (ipairs lines)]
    (io.write (ansi.truncate line cols) ansi.nl)))

(fn split-widths [cols ?ratio]
  (let [ratio (or ?ratio 0.4)
        left-cols (math.max 1 (math.floor (* (- cols 1) ratio)))
        right-cols (math.max 1 (- cols left-cols 1))
        divider-col (+ left-cols 1)]
    (values left-cols right-cols divider-col)))

(fn draw-split-row [screen-row
                    theme
                    left-row
                    right-line
                    left-cols
                    right-cols
                    divider-col]
  (terminal.cursor screen-row 1)
  (when left-row
    (write-row theme (ansi.truncate left-row.text left-cols) left-row.selected?
               left-cols))
  (terminal.cursor screen-row divider-col)
  (io.write (theme-store.color theme :muted "|"))
  (terminal.cursor screen-row (+ divider-col 1))
  (when right-line
    (io.write (ansi.truncate right-line right-cols))))

(fn list-rows [node]
  (or node.rows []))

(fn line-rows [node]
  (or node.lines []))

(fn legacy-body [view]
  (if view.preview
      (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                   view.split_ratio)
      (nodes.list view.rows)))

(fn draw-split-rows [theme node screen-rows cols]
  (let [(left-cols right-cols divider-col) (split-widths cols node.ratio)
        rows (list-rows node.left)
        preview (line-rows node.right)]
    (for [i 1 screen-rows]
      (draw-split-row (+ i 2) theme (. rows i) (. preview i) left-cols
                      right-cols divider-col))))

(fn draw-content [theme view rows cols]
  (let [screen-rows (math.max 1 (- rows 3))
        body (or view.body (legacy-body view))]
    (case body.type
      :split (draw-split-rows theme body screen-rows cols)
      :list (draw-rows theme (list-rows body) cols)
      :lines (draw-lines (line-rows body) cols)
      _ nil)))

(fn draw-notice [theme notice rows cols]
  (when notice
    (io.write ansi.esc "[" rows ";1H")
    (io.write (theme-store.color theme :notice (ansi.truncate notice cols)))))

(fn draw-warning [theme warning rows cols]
  (when warning
    (io.write ansi.esc "[" rows ";1H")
    (io.write (theme-store.color theme :warning (ansi.truncate warning cols)))))

(fn legacy-footer [view]
  (if view.prompt (nodes.footer :notice view.prompt)
      view.warning (nodes.footer :warning view.warning)
      (nodes.footer :notice view.notice)))

(fn draw-footer [theme view rows cols]
  (let [footer-node (or view.footer (legacy-footer view))]
    (when footer-node
      (case footer-node.type
        :warning (draw-warning theme footer-node.text rows cols)
        :notice (draw-notice theme footer-node.text rows cols)
        :prompt (draw-notice theme footer-node.text rows cols)
        _ nil))))

(fn draw [view-fn state]
  (let [(rows cols) (terminal.terminal-size)
        theme (or state.theme theme-store.default)]
    (let [view (view-fn state rows cols)]
      (draw-header theme view cols)
      (draw-content theme view rows cols)
      (draw-footer theme view rows cols)
      (io.flush))))

{: draw : split-widths}
