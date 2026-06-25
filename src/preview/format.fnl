(local symbols (require :tui.symbols))
(local tui (require :tui.core))
(local word-diff (require :preview.word-diff))

(fn header [state title]
  (let [divider (string.rep symbols.line.horizontal (tui.visible-length title))]
    [title (tui.color state.theme :muted divider)]))

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

(fn empty-preview [state]
  [(tui.color state.theme :muted "No preview for this file.")])

(fn change-lines [state removed added]
  (let [out []
        n (math.max (length removed) (length added))
        spans (fcollect [i 1 n] (word-diff.spans (. removed i) (. added i)))]
    (each [i old (ipairs removed)]
      (let [emph (word-diff.emphasize state.theme old (?. spans i :old)
                                      :emphasis-deleted)]
        (table.insert out (tui.color state.theme :status-deleted (.. " " emph)))))
    (each [i new (ipairs added)]
      (let [emph (word-diff.emphasize state.theme new (?. spans i :new)
                                      :emphasis-added)]
        (table.insert out (tui.color state.theme :status-added (.. " " emph)))))
    out))

(fn flush [state acc]
  (each [_ line (ipairs (change-lines state acc.removed acc.added))]
    (table.insert acc.out line))
  (set acc.removed [])
  (set acc.added []))

(fn diff-path [line]
  (let [stripped (line:sub 5)
        (trimmed _) (stripped:gsub "%s+$" "")]
    (if (= trimmed "/dev/null")
        nil
        (or (trimmed:match "^[ab]/(.+)$") trimmed))))

(fn step [state acc line]
  (let [first (line:sub 1 1)]
    (if (line:match "^diff ")
        (do
          (flush state acc)
          (set acc.in-hunk? false))
        (line:match "^@@")
        (do
          (flush state acc)
          (set acc.in-hunk? true)
          (table.insert acc.out (tui.color state.theme :muted line)))
        (not acc.in-hunk?)
        (if (line:match "^index ") nil
            (line:match "^%-%-%- ") (set acc.old-path (diff-path line))
            (line:match "^%+%+%+ ") (set acc.new-path (diff-path line))
            (table.insert acc.out (color-line state line)))
        (= first "+")
        (table.insert acc.added (line:sub 2))
        (= first "-")
        (table.insert acc.removed (line:sub 2))
        (= first "\\")
        nil
        (do
          (flush state acc)
          (table.insert acc.out (color-line state line))))))

(fn diff-lines [state output]
  (let [acc {:out [] :removed [] :added [] :in-hunk? false}]
    (each [line (string.gmatch (or output "") "[^\r\n]+")]
      (step state acc line))
    (flush state acc)
    (if (= 0 (length acc.out))
        (empty-preview state)
        (let [path (or acc.new-path acc.old-path)
              out (if path (header state path) [])]
          (each [_ line (ipairs acc.out)]
            (table.insert out line))
          out))))

(fn no-selection [state]
  [(tui.color state.theme :muted "No file selected.")])

(fn loading [state]
  [(tui.color state.theme :muted "Loading preview...")])

(fn asset [state entry]
  [(tui.color state.theme :muted (.. "Asset preview skipped: " entry.path))])

(fn binary [state path]
  [(tui.color state.theme :muted (.. "Binary file preview skipped: " path))])

(fn warning [state message]
  [(tui.color state.theme :warning message)])

{: asset
 : binary
 : color-line
 : diff-lines
 : empty-preview
 : header
 : line-color
 : loading
 : no-selection
 : warning}
