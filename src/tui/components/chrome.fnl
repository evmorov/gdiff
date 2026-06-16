(local ansi (require :tui.ansi))
(local nodes (require :tui.nodes))
(local split (require :tui.components.split))
(local symbols (require :tui.symbols))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn header-rule-symbol [ch col ?divider-col]
  (let [from-header? (= ch symbols.line.separator)
        from-body? (= col ?divider-col)]
    (if (and from-header? from-body?) symbols.line.join-cross
        from-header? symbols.line.join-up
        from-body? symbols.line.join-down
        symbols.line.horizontal)))

(fn split-divider-col [body cols]
  (when (and body (= body.type :split))
    (let [(_ _ divider-col) (split.widths cols body.ratio)]
      divider-col)))

(fn view-body [view]
  (or view.body
      (when view.preview
        (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                     view.split_ratio))))

(fn header-rule [header cols ?divider-col]
  (let [plain (ansi.strip-ansi header)]
    (var out "")
    (var i 1)
    (for [col 1 cols]
      (let [(ch next-i) (ansi.next-char plain i)]
        (set out (.. out (header-rule-symbol ch col ?divider-col)))
        (set i next-i)))
    out))

(fn footer-col? [?footer-cols col]
  (if (= (type ?footer-cols) :table)
      (. ?footer-cols col)
      (= col ?footer-cols)))

(fn bottom-rule-symbol [col ?divider-col ?footer-cols]
  (let [from-body? (= col ?divider-col)
        from-footer? (footer-col? ?footer-cols col)]
    (if (and from-body? from-footer?) symbols.line.join-cross
        from-body? symbols.line.join-up
        from-footer? symbols.line.join-down
        symbols.line.horizontal)))

(fn bottom-rule [cols ?divider-col ?footer-cols]
  (var out "")
  (for [col 1 cols]
    (set out (.. out (bottom-rule-symbol col ?divider-col ?footer-cols))))
  out)

(fn legacy-footer [view]
  (if view.prompt (nodes.footer :notice view.prompt)
      view.warning (nodes.footer :warning view.warning)
      (nodes.footer :notice view.notice)))

(fn view-footer [view]
  (or view.footer (legacy-footer view)))

(fn footer-right-text [right cols]
  (when right
    (ansi.truncate right (math.max 0 (- cols 2)))))

(fn footer-right-col [cols right]
  (when right
    (let [right (footer-right-text right cols)]
      (math.max 1 (- cols (ansi.visible-length right) 1)))))

(fn footer-left-width [cols right]
  (if right
      (math.max 0 (- cols (ansi.visible-length (footer-right-text right cols))
                     3))
      cols))

(fn add-text-separator-cols [rule-cols text start-col]
  (when text
    (let [plain (ansi.strip-ansi text)]
      (var i 1)
      (var visible 1)
      (while (<= i (length plain))
        (let [(ch next-i) (ansi.next-char plain i)]
          (when (= ch symbols.line.separator)
            (tset rule-cols (+ start-col visible -1) true))
          (set visible (+ visible 1))
          (set i next-i))))))

(fn footer-rule-cols [cols left right]
  (when (or left right)
    (let [rule-cols {}
          left (when left (ansi.truncate left (footer-left-width cols right)))
          right (footer-right-text right cols)
          right-col (footer-right-col cols right)]
      (add-text-separator-cols rule-cols left 1)
      (when right-col
        (tset rule-cols right-col true)
        (add-text-separator-cols rule-cols right (+ right-col 2)))
      rule-cols)))

(fn draw-header [ctx view]
  (let [header (ansi.truncate view.header ctx.cols)
        divider-col (split-divider-col (view-body view) ctx.cols)]
    (terminal.cursor 1 1)
    (terminal.clear-line)
    (io.write header ansi.nl)
    (terminal.clear-line)
    (io.write (theme.color ctx.theme :muted
                           (header-rule header ctx.cols divider-col))
              ansi.nl)))

(fn draw-bottom-rule [ctx view]
  (let [footer-node (view-footer view)
        divider-col (split-divider-col (view-body view) ctx.cols)
        footer-cols (footer-rule-cols ctx.cols
                                      (and footer-node footer-node.text)
                                      (and footer-node footer-node.right))]
    (io.write ansi.esc "[" (- ctx.rows 1) ";1H")
    (terminal.clear-line)
    (io.write (theme.color ctx.theme :muted
                           (bottom-rule ctx.cols divider-col footer-cols)))))

(fn footer-text-style [ctx footer-node text]
  (case footer-node.type
    :warning (theme.color ctx.theme :warning text)
    :notice (theme.color ctx.theme :notice text)
    :prompt (theme.color ctx.theme :notice text)
    _ text))

(fn styled-footer-text [ctx footer-node text]
  (var out "")
  (var chunk "")

  (fn flush-chunk []
    (when (> (length chunk) 0)
      (set out (.. out (footer-text-style ctx footer-node chunk)))
      (set chunk "")))

  (var i 1)
  (while (<= i (length text))
    (let [(ch next-i) (ansi.next-char text i)]
      (if (= ch symbols.line.separator)
          (do
            (flush-chunk)
            (set out (.. out (theme.color ctx.theme :muted ch))))
          (set chunk (.. chunk ch)))
      (set i next-i)))
  (flush-chunk)
  out)

(fn draw-footer-right [ctx right]
  (when right
    (let [right (footer-right-text right ctx.cols)
          col (footer-right-col ctx.cols right)]
      (io.write ansi.esc "[" ctx.rows ";" col "H")
      (io.write (theme.color ctx.theme :muted symbols.line.vertical) " ")
      (io.write right))))

(fn draw-footer [ctx view]
  (let [footer-node (view-footer view)]
    (terminal.cursor ctx.rows 1)
    (terminal.clear-line)
    (when footer-node
      (let [right footer-node.right
            left-width (footer-left-width ctx.cols right)
            left (when footer-node.text
                   (ansi.truncate footer-node.text left-width))]
        (when left
          (terminal.cursor ctx.rows 1)
          (io.write (styled-footer-text ctx footer-node left)))
        (draw-footer-right ctx right)))))

{: bottom-rule
 : draw-bottom-rule
 : draw-footer
 : draw-header
 : footer-rule-cols
 : footer-right-col
 : header-rule
 : legacy-footer
 : styled-footer-text}
