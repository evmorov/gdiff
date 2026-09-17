(local tui (require :tui.core))
(local scroll-util (require :util.scroll))
(local wrap (require :tui.wrap))

(fn content-width [split-ratio cols scroll?]
  (let [(_left-cols right-cols) (tui.components.split.widths cols split-ratio)]
    (math.max 0 (if scroll? (- right-cols 1) right-cols))))

(fn identity-map [lines]
  (fcollect [i 1 (length (or lines []))]
    i))

(fn display-lines [wrap? lines width]
  (if wrap?
      (wrap.lines lines width)
      (values lines (identity-map lines))))

(fn source-map [wrap? lines width]
  (let [(_ map) (display-lines wrap? lines width)]
    map))

(fn scroll? [lines visible]
  (scroll-util.scrolls? (length lines) visible))

(fn gutter-text [entry key]
  (if (= (type entry) :table)
      (or (. entry key) "")
      (if entry (tostring entry) "")))

(fn gutter-strings [numbers]
  (let [width (accumulate [w 0 _ n (ipairs (or numbers []))]
                (math.max w (tui.visible-length (gutter-text n :full))))]
    (if (= width 0)
        (values nil 0)
        (let [total (+ width 1)
              strings []]
          (each [_ n (ipairs numbers)]
            (if n
                (let [text (gutter-text n :full)]
                  (table.insert strings
                                (.. (string.rep " "
                                                (- width
                                                   (tui.visible-length text)))
                                    text " ")))
                (table.insert strings (string.rep " " total))))
          (values strings total)))))

(fn display-gutters [gutters width source-map]
  (when (and gutters (> width 0))
    (let [blank (string.rep " " width)
          seen {}]
      (icollect [_ src (ipairs source-map)]
        (if (. seen src)
            blank
            (do
              (tset seen src true)
              (or (. gutters src) blank)))))))

(fn wide-layout [state lines visible wide-width]
  (when (not (scroll? lines visible))
    (display-lines state.preview_wrap? lines wide-width)))

(fn lines-for-width [state lines gutter-labels visible cols]
  (let [(gutters gutter-width) (if gutter-labels
                                   (gutter-strings gutter-labels)
                                   (values nil 0))
        text-width (fn [scroll?]
                     (math.max 1
                               (- (content-width state.split_ratio cols scroll?)
                                  gutter-width)))
        wide-width (text-width false)
        (wide-lines wide-map) (wide-layout state lines visible wide-width)
        scrolls? (or (not wide-lines) (scroll? wide-lines visible))
        width (text-width scrolls?)
        wide-final? (and wide-lines (or (not scrolls?) (= width wide-width)))
        (display source-map) (if wide-final?
                                 (values wide-lines wide-map)
                                 (display-lines state.preview_wrap? lines width))]
    (values display source-map
            (display-gutters gutters gutter-width source-map))))

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

{: content-width : lines-for-width : scroll-state : source-map : visible-lines}
