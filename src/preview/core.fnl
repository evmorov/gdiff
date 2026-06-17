(local git (require :git.core))
(local preview-key (require :preview.key))
(local sys (require :platform.core))
(local tui (require :tui.core))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn line-color [line]
  (let [first (line:sub 1 1)]
    (if (or (line:match "^diff ") (line:match "^index ")
            (line:match "^%-%-%- ") (line:match "^%+%+%+ "))
        :muted
        (= first "+")
        :status-added
        (= first "-")
        :status-deleted
        (= first "@")
        :status-renamed
        nil)))

(fn color-line [state line]
  (let [line (or line "")
        color (line-color line)]
    (if color
        (tui.color state.theme color line)
        line)))

(fn lines-from-output [state output filtered?]
  (let [lines (icollect [line (string.gmatch (or output "") "[^\r\n]+")]
                (if filtered?
                    line
                    (color-line state line)))]
    (if (> (length lines) 0)
        lines
        [(tui.color state.theme :muted "No preview for this file.")])))

(fn lines [state entry]
  (if (not entry)
      [(tui.color state.theme :muted "No file selected.")]
      (let [key (preview-key.for-entry state.revision entry)
            cached (. state.preview_cache key)]
        (if cached
            cached
            (let [(output ok filtered?) (git.preview-output state.preview_context
                                                            state.revision entry)
                  lines (if ok
                            (lines-from-output state output filtered?)
                            [(tui.color state.theme :warning (sys.trim output))])]
              (tset state.preview_cache key lines)
              lines)))))

(fn warming? [state]
  (and state.preview_warm state.preview_warm.dir))

(fn loading-lines [state]
  [(tui.color state.theme :muted "Loading preview...")])

(fn nonblocking-lines [state entry]
  (if (not entry)
      [(tui.color state.theme :muted "No file selected.")]
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
  (set state.preview_scroll (clamp scroll 0 (max-scroll state entry))))

(fn set-scroll-for-lines [state lines scroll]
  (let [max-scroll (math.max 0 (- (length lines) (row-count state)))]
    (set state.preview_scroll (clamp scroll 0 max-scroll))))

(fn reset-scroll [state]
  (set state.preview_scroll 0)
  (set state.preview_x_scroll 0)
  (set state.preview_x_max_scroll 0))

(fn scroll [state entry delta]
  (set-scroll state entry (+ (or state.preview_scroll 0) delta)))

(fn scroll-page-down [state entry]
  (scroll state entry (page-step state)))

(fn scroll-page-up [state entry]
  (scroll state entry (- (page-step state))))

(fn scroll-horizontal [state delta]
  (set state.preview_x_scroll
       (clamp (+ (or state.preview_x_scroll 0) delta) 0
              (or state.preview_x_max_scroll 0))))

(fn max-line-width [lines]
  (accumulate [width 0 _ line (ipairs (or lines []))]
    (math.max width (tui.visible-length line))))

(fn set-horizontal-scroll-limit [state lines width]
  (let [max-scroll (math.max 0 (- (max-line-width lines) (math.max 0 width)))]
    (set state.preview_x_max_scroll max-scroll)
    (set state.preview_x_scroll
         (clamp (or state.preview_x_scroll 0) 0 max-scroll))))

(fn visible-lines [state entry visible ?opts]
  (let [visible (math.max 1 visible)
        lines (if (and ?opts ?opts.nonblocking?)
                  (nonblocking-lines state entry)
                  (lines state entry))]
    (set state.preview_rows visible)
    (set state.preview_total (length lines))
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
 : reset-scroll
 : scroll-info
 : scroll-horizontal
 : scroll-page-down
 : scroll-page-up
 : set-horizontal-scroll-limit
 : visible-lines}
