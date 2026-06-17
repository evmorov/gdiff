(local git (require :git.core))
(local assets (require :preview.assets))
(local format (require :preview.format))
(local preview-key (require :preview.key))
(local sys (require :platform.core))
(local tui (require :tui.core))
(local math-util (require :util.math))

(import-macros {: set-fields} :state.macros)

(fn lines [state entry]
  (if (not entry)
      (format.no-selection state)
      (let [key (preview-key.for-entry state.revision entry)
            cached (. state.preview_cache key)]
        (if cached
            cached
            (assets.asset? entry)
            (let [lines (format.asset state entry)]
              (tset state.preview_cache key lines)
              lines)
            (let [(output ok filtered?) (git.preview-output state.preview_context
                                                            state.revision entry)
                  lines (if ok
                            (format.output-lines state output filtered?)
                            (format.warning state (sys.trim output)))]
              (tset state.preview_cache key lines)
              lines)))))

(fn warming? [state]
  (and state.preview_warm state.preview_warm.dir))

(fn loading-lines [state]
  (format.loading state))

(fn nonblocking-lines [state entry]
  (if (not entry)
      (format.no-selection state)
      (let [key (preview-key.for-entry state.revision entry)
            cached (. state.preview_cache key)]
        (if cached cached
            (warming? state) (loading-lines state)
            (lines state entry)))))

(fn row-count [state]
  (or state.preview_rows 1))

(fn page-step [state]
  (math.max 1 (math.floor (/ (row-count state) 2))))

(fn max-scroll [state entry]
  (math.max 0 (- (length (lines state entry)) (row-count state))))

(fn set-scroll [state entry scroll]
  (let [before (or state.preview_scroll 0)
        after (math-util.clamp scroll 0 (max-scroll state entry))]
    (set state.preview_scroll after)
    (not (= before after))))

(fn set-scroll-for-lines [state lines scroll]
  (let [before (or state.preview_scroll 0)
        max-scroll (math.max 0 (- (length lines) (row-count state)))
        after (math-util.clamp scroll 0 max-scroll)]
    (set state.preview_scroll after)
    (not (= before after))))

(fn reset-scroll [state]
  (set-fields state [:preview_scroll 0] [:preview_x_scroll 0]
              [:preview_x_max_scroll 0]))

(fn scroll [state entry delta]
  (set-scroll state entry (+ (or state.preview_scroll 0) delta)))

(fn scroll-page-down [state entry]
  (scroll state entry (page-step state)))

(fn scroll-page-up [state entry]
  (scroll state entry (- (page-step state))))

(fn scroll-horizontal [state delta]
  (let [before (or state.preview_x_scroll 0)
        after (math-util.clamp (+ before delta) 0
                               (or state.preview_x_max_scroll 0))]
    (set state.preview_x_scroll after)
    (not (= before after))))

(fn max-line-width [lines]
  (accumulate [width 0 _ line (ipairs (or lines []))]
    (math.max width (tui.visible-length line))))

(fn set-horizontal-scroll-limit [state lines width]
  (let [max-scroll (math.max 0 (- (max-line-width lines) (math.max 0 width)))]
    (set-fields state [:preview_x_max_scroll max-scroll]
                [:preview_x_scroll
                 (math-util.clamp (or state.preview_x_scroll 0) 0 max-scroll)])))

(fn visible-lines [state entry visible ?opts]
  (let [visible (math.max 1 visible)
        lines (if (and ?opts ?opts.nonblocking?)
                  (nonblocking-lines state entry)
                  (lines state entry))]
    (set-fields state [:preview_rows visible] [:preview_total (length lines)])
    (set-scroll-for-lines state lines (or state.preview_scroll 0))
    (let [first (+ state.preview_scroll 1)
          last (math.min (length lines) (+ state.preview_scroll visible))]
      (if (> first last)
          []
          (fcollect [i first last]
            (. lines i))))))

(fn scroll-info [state]
  (let [visible (or state.preview_rows 0)
        total (or state.preview_total 0)]
    (when (> total visible)
      {:offset (or state.preview_scroll 0) :visible visible :total total})))

{: lines
 : nonblocking-lines
 : page-step
 : reset-scroll
 : scroll
 : scroll-info
 : scroll-horizontal
 : scroll-page-down
 : scroll-page-up
 : set-horizontal-scroll-limit
 : visible-lines}
