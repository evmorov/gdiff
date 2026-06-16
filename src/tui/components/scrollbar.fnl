(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(local thumb "█")
(local track "│")

(fn visible? [scroll height]
  (if (and scroll (> height 0) (> (or scroll.total 0) (or scroll.visible 0)))
      true))

(fn thumb-size [scroll height]
  (math.max 1 (math.ceil (/ (* height scroll.visible) scroll.total))))

(fn thumb-range [scroll height]
  (let [size (thumb-size scroll height)
        max-offset (math.max 1 (- scroll.total scroll.visible))
        max-start (math.max 0 (- height size))
        start (+ 1 (math.floor (/ (* max-start scroll.offset) max-offset)))]
    (values start (+ start size -1))))

(fn marker [scroll height row]
  (let [(start finish) (thumb-range scroll height)]
    (if (and (>= row start) (<= row finish)) thumb track)))

(fn draw [ctx scroll row screen-row col height]
  (when (visible? scroll height)
    (terminal.cursor screen-row col)
    (io.write (theme.color ctx.theme :muted (marker scroll height row)))))

{: draw : marker : thumb-range : visible?}
