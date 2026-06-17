(local symbols (require :tui.symbols))
(local surface (require :tui.surface))
(local theme (require :tui.theme))

(local thumb symbols.line.scroll-thumb)

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

(fn marker [scroll height row ?thumb]
  (let [(start finish) (thumb-range scroll height)]
    (if (and (>= row start) (<= row finish)) (or ?thumb thumb))))

(fn draw [ctx scroll row screen-row col height]
  (when (visible? scroll height)
    (let [mark (marker scroll height row)]
      (when mark
        (surface.write-at screen-row col (theme.color ctx.theme :muted mark))))))

{: draw : marker : thumb-range : visible?}
