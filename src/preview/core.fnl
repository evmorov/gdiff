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
        :dim
        (= first "+")
        :added
        (= first "-")
        :deleted
        (= first "@")
        :renamed
        nil)))

(fn color-line [line]
  (let [line (or line "")
        color (line-color line)]
    (if color
        (tui.color color line)
        line)))

(fn lines-from-output [output filtered?]
  (let [lines (icollect [line (string.gmatch (or output "") "[^\r\n]+")]
                (if filtered?
                    line
                    (color-line line)))]
    (if (> (length lines) 0)
        lines
        [(tui.color :dim "No preview for this file.")])))

(fn lines [state entry]
  (if (not entry)
      [(tui.color :dim "No file selected.")]
      (let [key (preview-key.for-entry state.revision entry)
            cached (. state.preview_cache key)]
        (if cached
            cached
            (let [(output ok filtered?) (git.preview-output state.preview_context
                                                            state.revision entry)
                  lines (if ok
                            (lines-from-output output filtered?)
                            [(tui.color :deleted (sys.trim output))])]
              (tset state.preview_cache key lines)
              lines)))))

(fn warming? [state]
  (and state.preview_warm state.preview_warm.dir))

(fn loading-lines []
  [(tui.color :dim "Loading preview...")])

(fn nonblocking-lines [state entry]
  (if (not entry)
      [(tui.color :dim "No file selected.")]
      (let [key (preview-key.for-entry state.revision entry)
            cached (. state.preview_cache key)]
        (if cached cached
            (warming? state) (loading-lines)
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
  (set state.preview_scroll 0))

(fn scroll [state entry delta]
  (set-scroll state entry (+ (or state.preview_scroll 0) delta)))

(fn scroll-page-down [state entry]
  (scroll state entry (page-step state)))

(fn scroll-page-up [state entry]
  (scroll state entry (- (page-step state))))

(fn visible-lines [state entry rows ?opts]
  (let [usable (math.max 1 (- rows 3))
        lines (if (and ?opts ?opts.nonblocking?)
                  (nonblocking-lines state entry)
                  (lines state entry))]
    (set state.preview_rows usable)
    (set-scroll-for-lines state lines (or state.preview_scroll 0))
    (let [first (+ state.preview_scroll 1)
          last (math.min (length lines) (+ state.preview_scroll usable))]
      (if (> first last)
          []
          (fcollect [i first last]
            (. lines i))))))

{: lines
 : nonblocking-lines
 : reset-scroll
 : scroll-page-down
 : scroll-page-up
 : visible-lines}
