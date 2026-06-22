(local ansi (require :tui.ansi))
(local surface (require :tui.surface))
(local symbols (require :tui.symbols))
(local theme (require :tui.theme))

(fn content-width [title lines]
  (var width (ansi.visible-length title))
  (each [_ line (ipairs lines)]
    (set width (math.max width (ansi.visible-length line))))
  width)

(fn muted [ctx text]
  (theme.color ctx.theme :muted text))

(fn rule-line [ctx left right inner]
  (muted ctx (.. left (string.rep symbols.line.horizontal inner) right)))

(fn body-line [ctx text text-width]
  (let [bar (muted ctx symbols.line.vertical)]
    (.. bar " " (ansi.pad-right text text-width) " " bar)))

(fn center [text width]
  (let [pad (math.floor (/ (- width (ansi.visible-length text)) 2))]
    (if (< 0 pad) (.. (string.rep " " pad) text) text)))

(fn box-rows [ctx title lines text-width inner]
  (let [rows [(rule-line ctx symbols.line.corner-top-left
                         symbols.line.corner-top-right inner)
              (body-line ctx (center title text-width) text-width)
              (rule-line ctx symbols.line.tee-left symbols.line.tee-right inner)]]
    (each [_ line (ipairs lines)]
      (table.insert rows (body-line ctx line text-width)))
    (table.insert rows
                  (rule-line ctx symbols.line.corner-bottom-left
                             symbols.line.corner-bottom-right inner))
    rows))

(fn draw [ctx node]
  (let [title (or node.title "")
        lines (or node.lines [])
        text-width (content-width title lines)
        inner (+ text-width 2)
        box-width (+ inner 2)
        rows (box-rows ctx title lines text-width inner)
        start-row (math.max 1 (+ (math.floor (/ (- ctx.rows (length rows)) 2))
                                 1))
        start-col (math.max 1 (+ (math.floor (/ (- ctx.cols box-width) 2)) 1))]
    (each [i line (ipairs rows)]
      (surface.write-at (+ start-row i -1) start-col line))))

{: draw}
