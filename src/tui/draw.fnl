(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local nodes (require :tui.nodes))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn write-row [ctx line selected? width ?newline]
  (io.write (if selected? (theme.selected-row ctx.theme line width) line))
  (when ?newline
    (io.write ansi.nl)))

(fn draw-header [ctx view]
  (io.write ansi.esc "[2J" ansi.esc "[H")
  (io.write (ansi.truncate view.header ctx.cols) ansi.nl)
  (io.write (theme.color ctx.theme :muted (string.rep "-" ctx.cols)) ansi.nl))

(fn draw-rows [ctx rows width]
  (each [_ row (ipairs rows)]
    (write-row ctx (ansi.truncate row.text width) row.selected? width true)))

(fn draw-lines [lines width]
  (each [_ line (ipairs lines)]
    (io.write (ansi.truncate line width) ansi.nl)))

(fn split-widths [cols ?ratio]
  (let [ratio (or ?ratio 0.4)
        left-cols (math.max 1 (math.floor (* (- cols 1) ratio)))
        right-cols (math.max 1 (- cols left-cols 1))
        divider-col (+ left-cols 1)]
    (values left-cols right-cols divider-col)))

(fn draw-split-row [screen-row
                    ctx
                    left-row
                    right-line
                    left-cols
                    right-cols
                    divider-col]
  (terminal.cursor screen-row 1)
  (when left-row
    (write-row ctx (ansi.truncate left-row.text left-cols) left-row.selected?
               left-cols))
  (terminal.cursor screen-row divider-col)
  (io.write (theme.color ctx.theme :muted "|"))
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

(fn draw-split-rows [ctx node]
  (let [(left-cols right-cols divider-col) (split-widths ctx.cols node.ratio)
        rows (list-rows node.left)
        preview (line-rows node.right)]
    (for [i 1 (context.body-rows ctx)]
      (draw-split-row (+ i 2) ctx (. rows i) (. preview i) left-cols right-cols
                      divider-col))))

(fn draw-content [ctx view]
  (let [body (or view.body (legacy-body view))]
    (case body.type
      :split (draw-split-rows ctx body)
      :list (draw-rows ctx (list-rows body) ctx.cols)
      :lines (draw-lines (line-rows body) ctx.cols)
      _ nil)))

(fn draw-notice [ctx notice]
  (when notice
    (io.write ansi.esc "[" ctx.rows ";1H")
    (io.write (theme.color ctx.theme :notice (ansi.truncate notice ctx.cols)))))

(fn draw-warning [ctx warning]
  (when warning
    (io.write ansi.esc "[" ctx.rows ";1H")
    (io.write (theme.color ctx.theme :warning (ansi.truncate warning ctx.cols)))))

(fn legacy-footer [view]
  (if view.prompt (nodes.footer :notice view.prompt)
      view.warning (nodes.footer :warning view.warning)
      (nodes.footer :notice view.notice)))

(fn draw-footer [ctx view]
  (let [footer-node (or view.footer (legacy-footer view))]
    (when footer-node
      (case footer-node.type
        :warning (draw-warning ctx footer-node.text)
        :notice (draw-notice ctx footer-node.text)
        :prompt (draw-notice ctx footer-node.text)
        _ nil))))

(fn draw [view-fn state]
  (let [(rows cols) (terminal.terminal-size)
        ctx (context.new rows cols state.theme)]
    (let [view (view-fn state ctx.rows ctx.cols)]
      (draw-header ctx view)
      (draw-content ctx view)
      (draw-footer ctx view)
      (io.flush))))

{: draw : split-widths}
