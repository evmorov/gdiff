(local symbols (require :tui.symbols))
(local tui (require :tui.core))
(local word-diff (require :preview.word-diff))
(local diff-parse (require :preview.diff-parse))

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
        pairs (word-diff.align removed added)]
    (each [_ p (ipairs pairs)]
      (when p.old
        (let [old (. removed p.old)
              ?span (when p.new
                      (. (word-diff.spans old (. added p.new)) :old))
              emph (word-diff.emphasize state.theme old ?span :emphasis-deleted)]
          (table.insert out (tui.color state.theme :status-deleted emph)))))
    (each [_ p (ipairs pairs)]
      (when p.new
        (let [new (. added p.new)
              ?span (when p.old
                      (. (word-diff.spans (. removed p.old) new) :new))
              emph (word-diff.emphasize state.theme new ?span :emphasis-added)]
          (table.insert out (tui.color state.theme :status-added emph)))))
    out))

(fn diff-lines [state output]
  (let [acc {:out []}
        handlers {:change (fn [removed added]
                            (each [_ line (ipairs (change-lines state removed
                                                                added))]
                              (table.insert acc.out line)))
                  :hunk (fn [line]
                          (table.insert acc.out
                                        (tui.color state.theme :muted line)))
                  :context (fn [text] (table.insert acc.out text))
                  :meta (fn [line]
                          (table.insert acc.out (color-line state line)))
                  :old-path (fn [path] (set acc.old-path path))
                  :new-path (fn [path] (set acc.new-path path))}]
    (diff-parse.parse output handlers)
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
