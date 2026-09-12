(local moves (require :git.moves))
(local symbols (require :tui.symbols))
(local tui (require :tui.core))
(local word-diff (require :preview.word-diff))
(local diff-walk (require :preview.diff-walk))
(local diff-parse (require :preview.diff-parse))
(local comments (require :preview.comments))
(local line-moves (require :preview.line-moves))
(local highlight (require :preview.highlight))
(local theme (require :tui.theme))
(local str (require :util.string))

(fn move-note [state ?entry]
  (let [note (moves.note (or ?entry {}))]
    (if (= note "") "" (tui.color state.theme :status-renamed note))))

(fn header [state path ?entry]
  (let [text (.. (str.basename path) (move-note state ?entry))
        divider (string.rep symbols.line.horizontal (tui.visible-length text))]
    [text (tui.color state.theme :muted divider)]))

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

(fn emphasized-change [state raw ?span style-key mark-whitespace? ?styled]
  (if (and mark-whitespace? (word-diff.whitespace-only? raw))
      (word-diff.emphasize-whitespace state.theme raw
                                      (. whitespace-styles style-key))
      ?styled
      (highlight.emphasize-styled state.theme ?styled raw ?span style-key)
      (word-diff.emphasize state.theme raw ?span style-key)))

(fn role-line [state role text ?styled]
  (if ?styled
      (theme.tint state.theme (highlight.tint-role role) text)
      (tui.color state.theme role text)))

(local side-map highlight.side-map)

(fn moved-line [state raw side mark]
  (tui.color state.theme :moved (.. raw (line-moves.annotation side mark))))

(fn change-lines [state removed added ctx]
  (let [out []
        pairs (word-diff.align removed added)]
    (each [_ p (ipairs pairs)]
      (when p.old
        (let [old (. removed p.old)
              ?mark (. ctx.moves.old (+ ctx.old-no p.old -1))]
          (if ?mark
              (table.insert out (moved-line state old :old ?mark))
              (let [?span (when (and p.new (not p.loose?))
                            (. (word-diff.spans old (. added p.new)) :old))
                    ?styled (highlight.styled-line (side-map ctx.highlight :old)
                                                   (+ ctx.old-no p.old -1) old)
                    emph (emphasized-change state old ?span :emphasis-deleted
                                            ctx.whitespace-hunk? ?styled)
                    role (if (ctx.comment? old) :comment-deleted
                             :status-deleted)]
                (table.insert out (role-line state role emph ?styled)))))))
    (each [_ p (ipairs pairs)]
      (when p.new
        (let [new (. added p.new)
              ?mark (. ctx.moves.new (+ ctx.new-no p.new -1))]
          (if ?mark
              (table.insert out (moved-line state new :new ?mark))
              (let [?span (when (and p.old (not p.loose?))
                            (. (word-diff.spans (. removed p.old) new) :new))
                    ?styled (highlight.styled-line (side-map ctx.highlight :new)
                                                   (+ ctx.new-no p.new -1) new)
                    emph (emphasized-change state new ?span :emphasis-added
                                            ctx.whitespace-hunk? ?styled)
                    role (if (ctx.comment? new) :comment-added :status-added)]
                (table.insert out (role-line state role emph ?styled)))))))
    out))

(fn diff-lines [state output ?entry ?highlight]
  (let [ws-hunks (diff-parse.whitespace-only-hunks output)
        moves (line-moves.detect output)
        out []
        numbers []
        refs []
        push (fn [line ?number ?ref]
               (table.insert out line)
               (table.insert numbers (or ?number false))
               (table.insert refs (or ?ref false)))
        comment? (fn [acc text]
                   (comments.comment-line? (or acc.new-path acc.old-path) text))
        hidden? (fn [acc text]
                  (and state.hide_comments? (comment? acc text)))
        acc (diff-walk.walk output
                            {:change (fn [acc removed added]
                                       (let [lines (change-lines state removed
                                                                 added
                                                                 {:comment? (fn [text]
                                                                              (comment? acc
                                                                                        text))
                                                                  : moves
                                                                  :highlight ?highlight
                                                                  :whitespace-hunk? (. ws-hunks
                                                                                       acc.hunk-no)
                                                                  :old-no acc.old-no
                                                                  :new-no acc.new-no})
                                             removed-count (length removed)]
                                         (each [i line (ipairs lines)]
                                           (if (<= i removed-count)
                                               (when (not (hidden? acc
                                                                   (. removed i)))
                                                 (push line (+ acc.old-no i -1)
                                                       {:side :old
                                                        :no (+ acc.old-no i -1)}))
                                               (when (not (hidden? acc
                                                                   (. added
                                                                      (- i
                                                                         removed-count))))
                                                 (push line
                                                       (+ acc.new-no
                                                          (- i removed-count) -1)
                                                       {:side :new
                                                        :no (+ acc.new-no
                                                               (- i
                                                                  removed-count)
                                                               -1)}))))))
                             :hunk (fn [_acc line]
                                     (push (tui.color state.theme :muted line)))
                             :context (fn [acc text]
                                        (when (not (hidden? acc text))
                                          (push (or (highlight.styled-line (side-map ?highlight
                                                                                     :new)
                                                                           acc.new-no
                                                                           text)
                                                    text)
                                                acc.new-no
                                                {:side :new :no acc.new-no})))
                             :meta (fn [_acc line]
                                     (push (color-line state line)))})]
    (let [header-path (or acc.new-path acc.old-path)]
      (when (and header-path (< 0 (length out)))
        (each [i line (ipairs (header state header-path ?entry))]
          (table.insert out i line)
          (table.insert numbers i false)
          (table.insert refs i false))))
    (if (= 0 (length out))
        (values (empty-preview state) nil)
        (values out numbers refs))))

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
