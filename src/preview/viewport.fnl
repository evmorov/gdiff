(local tui (require :tui.core))
(local scroll-util (require :util.scroll))
(local wrap (require :tui.wrap))

(fn content-width [split-ratio cols scroll?]
  (let [(_left-cols right-cols) (tui.components.split.widths cols split-ratio)]
    (math.max 0 (if scroll? (- right-cols 1) right-cols))))

(fn display-lines [wrap? lines width]
  (if wrap?
      (wrap.lines lines width)
      lines))

;; Maps each display row back to the source (logical) line it came from, so a
;; wrapped line resolves to a single logical line when yanking.
(fn source-map [wrap? lines width]
  (if wrap?
      (let [out []]
        (each [source-index text (ipairs (or lines []))]
          (for [_ 1 (length (wrap.line text width))]
            (table.insert out source-index)))
        out)
      (fcollect [i 1 (length (or lines []))]
        i)))

(fn scroll? [lines visible]
  (scroll-util.scrolls? (length lines) visible))

(fn lines-for-width [state lines visible cols]
  (let [wide-width (content-width state.split_ratio cols false)
        wide-lines (display-lines state.preview_wrap? lines wide-width)
        scroll? (scroll? wide-lines visible)
        width (content-width state.split_ratio cols scroll?)
        narrow? (and state.preview_wrap? scroll? (not (= width wide-width)))
        final-width (if narrow? width wide-width)
        display (if narrow? (display-lines state.preview_wrap? lines width)
                    wide-lines)]
    (values display (source-map state.preview_wrap? lines final-width))))

(fn scroll-state [lines visible scroll]
  (let [total (length lines)]
    {:offset (scroll-util.clamp-offset scroll total visible) : total : visible}))

(fn visible-lines [lines scroll-state]
  (let [first (+ (or scroll-state.offset 0) 1)
        last (math.min scroll-state.total
                       (+ (or scroll-state.offset 0) scroll-state.visible))]
    (if (> first last)
        []
        (fcollect [i first last]
          (. lines i)))))

{: content-width
 : display-lines
 : lines-for-width
 : scroll-state
 : scroll?
 : source-map
 : visible-lines}
