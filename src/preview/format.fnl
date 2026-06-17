(local tui (require :tui.core))

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

(fn output-lines [state output filtered?]
  (let [lines (icollect [line (string.gmatch (or output "") "[^\r\n]+")]
                (if filtered?
                    line
                    (color-line state line)))]
    (if (> (length lines) 0)
        lines
        [(tui.color state.theme :muted "No preview for this file.")])))

(fn no-selection [state]
  [(tui.color state.theme :muted "No file selected.")])

(fn loading [state]
  [(tui.color state.theme :muted "Loading preview...")])

(fn asset [state entry]
  [(tui.color state.theme :muted (.. "Asset preview skipped: " entry.path))])

(fn warning [state message]
  [(tui.color state.theme :warning message)])

{: asset
 : color-line
 : line-color
 : loading
 : no-selection
 : output-lines
 : warning}
