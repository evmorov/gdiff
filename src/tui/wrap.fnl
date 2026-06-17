(local ansi (require :tui.ansi))
(local symbols (require :tui.symbols))

(fn line [text width]
  (let [width (math.max 1 width)
        line-width (ansi.visible-length text)
        continued-width (math.max 1 (- width 1))]
    (if (<= line-width width)
        [text]
        (let [out []]
          (var offset 0)
          (while (< offset line-width)
            (let [remaining (- line-width offset)
                  continued? (> remaining width)
                  chunk-width (if continued? continued-width width)
                  chunk (ansi.window text offset chunk-width)]
              (table.insert out (if continued?
                                    (.. chunk symbols.line.wrap-arrow)
                                    chunk))
              (set offset (+ offset chunk-width))))
          out))))

(fn lines [source width]
  (let [out []]
    (each [_ text (ipairs (or source []))]
      (each [_ part (ipairs (line text width))]
        (table.insert out part)))
    out))

{: line : lines}
