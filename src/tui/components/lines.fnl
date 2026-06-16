(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local scrollbar (require :tui.components.scrollbar))
(local terminal (require :tui.terminal))

(fn rows [node]
  (or node.lines []))

(fn draw [ctx node ?width]
  (let [width (or ?width ctx.cols)
        scroll? (scrollbar.visible? node.scroll (context.body-rows ctx))
        content-width (if scroll? (- width 1) width)]
    (for [i 1 (context.body-rows ctx)]
      (let [line (. (rows node) i)]
        (terminal.cursor (+ i 2) 1)
        (terminal.clear-line)
        (when (and line (> content-width 0))
          (io.write (ansi.truncate line content-width)))
        (when scroll?
          (scrollbar.draw ctx node.scroll i (+ i 2) width
                          (context.body-rows ctx)))
        (io.write ansi.nl)))))

{: draw : rows}
