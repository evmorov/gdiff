(local symbols (require :tui.symbols))
(local tui (require :tui.core))
(local word-diff (require :preview.word-diff))
(local diff-parse (require :preview.diff-parse))
(local comments (require :preview.comments))

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

(local whitespace-styles
       {:emphasis-deleted :whitespace-deleted
        :emphasis-added :whitespace-added})

(fn emphasized-change [state raw ?span style-key mark-whitespace?]
  (if (and mark-whitespace? (word-diff.whitespace-only? raw))
      (word-diff.emphasize-whitespace state.theme raw
                                      (. whitespace-styles style-key))
      (word-diff.emphasize state.theme raw ?span style-key)))

(fn change-lines [state removed added comment? ?whitespace-hunk?]
  (let [out []
        pairs (word-diff.align removed added)]
    (each [_ p (ipairs pairs)]
      (when p.old
        (let [old (. removed p.old)
              ?span (when p.new
                      (. (word-diff.spans old (. added p.new)) :old))
              emph (emphasized-change state old ?span :emphasis-deleted
                                      ?whitespace-hunk?)
              role (if (comment? old) :comment-deleted :status-deleted)]
          (table.insert out (tui.color state.theme role emph)))))
    (each [_ p (ipairs pairs)]
      (when p.new
        (let [new (. added p.new)
              ?span (when p.old
                      (. (word-diff.spans (. removed p.old) new) :new))
              emph (emphasized-change state new ?span :emphasis-added
                                      ?whitespace-hunk?)
              role (if (comment? new) :comment-added :status-added)]
          (table.insert out (tui.color state.theme role emph)))))
    out))

(fn diff-lines [state output]
  (let [ws-hunks (diff-parse.whitespace-only-hunks output)
        acc {:out [] :numbers [] :refs [] :old-no 1 :new-no 1 :hunk-no 0}
        comment? (fn [text]
                   (comments.comment-line? (or acc.new-path acc.old-path) text))
        hidden? (fn [text] (and state.hide_comments? (comment? text)))
        push (fn [line ?number ?ref]
               (table.insert acc.out line)
               (table.insert acc.numbers (or ?number false))
               (table.insert acc.refs (or ?ref false)))
        handlers {:change (fn [removed added]
                            (let [lines (change-lines state removed added
                                                      comment?
                                                      (. ws-hunks acc.hunk-no))
                                  removed-count (length removed)]
                              (each [i line (ipairs lines)]
                                (if (<= i removed-count)
                                    (when (not (hidden? (. removed i)))
                                      (push line (+ acc.old-no i -1)
                                            {:side :old
                                             :no (+ acc.old-no i -1)}))
                                    (when (not (hidden? (. added
                                                           (- i removed-count))))
                                      (push line
                                            (+ acc.new-no (- i removed-count)
                                               -1)
                                            {:side :new
                                             :no (+ acc.new-no
                                                    (- i removed-count) -1)}))))
                              (set acc.old-no (+ acc.old-no removed-count))
                              (set acc.new-no (+ acc.new-no (length added)))))
                  :hunk (fn [line]
                          (set acc.hunk-no (+ acc.hunk-no 1))
                          (push (tui.color state.theme :muted line))
                          (let [(old new) (diff-parse.hunk-start line)]
                            (when old (set acc.old-no old))
                            (when new (set acc.new-no new))))
                  :context (fn [text]
                             (when (not (hidden? text))
                               (push text acc.new-no
                                     {:side :new :no acc.new-no}))
                             (set acc.old-no (+ acc.old-no 1))
                             (set acc.new-no (+ acc.new-no 1)))
                  :meta (fn [line] (push (color-line state line)))
                  :old-path (fn [path] (set acc.old-path path))
                  :new-path (fn [path] (set acc.new-path path))}]
    (diff-parse.parse output handlers)
    (if (= 0 (length acc.out))
        (values (empty-preview state) nil)
        (let [path (or acc.new-path acc.old-path)
              out []
              numbers []
              refs []]
          (each [_ line (ipairs (if path (header state path) []))]
            (table.insert out line)
            (table.insert numbers false)
            (table.insert refs false))
          (each [i line (ipairs acc.out)]
            (table.insert out line)
            (table.insert numbers (. acc.numbers i))
            (table.insert refs (. acc.refs i)))
          (values out numbers refs)))))

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
