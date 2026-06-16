(local ansi (require :tui.ansi))

(fn rows [node]
  (or node.lines []))

(fn draw [ctx node ?width]
  (let [width (or ?width ctx.cols)]
    (each [_ line (ipairs (rows node))]
      (io.write (ansi.truncate line width) ansi.nl))))

{: draw : rows}
