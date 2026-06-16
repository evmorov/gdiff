(local ansi (require :tui.ansi))
(local rule (require :tui.components.rule))
(local symbols (require :tui.symbols))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn right-text [right cols]
  (when right
    (ansi.truncate right (math.max 0 (- cols 2)))))

(fn right-col [cols right]
  (when right
    (let [right (right-text right cols)]
      (math.max 1 (- cols (ansi.visible-length right) 1)))))

(fn left-width [cols right]
  (if right
      (math.max 0 (- cols (ansi.visible-length (right-text right cols)) 3))
      cols))

(fn rule-cols [cols left right]
  (when (or left right)
    (let [cols* {}
          left (when left (ansi.truncate left (left-width cols right)))
          right (right-text right cols)
          right-col* (right-col cols right)]
      (each [col _ (pairs (rule.separator-cols left 1))]
        (tset cols* col true))
      (when right-col*
        (tset cols* right-col* true)
        (each [col _ (pairs (rule.separator-cols right (+ right-col* 2)))]
          (tset cols* col true)))
      cols*)))

(fn text-style [ctx footer text]
  (case footer.type
    :warning (theme.color ctx.theme :warning text)
    :notice (theme.color ctx.theme :notice text)
    :prompt (theme.color ctx.theme :notice text)
    _ text))

(fn styled-text [ctx footer text]
  (var out "")
  (var chunk "")

  (fn flush-chunk []
    (when (> (length chunk) 0)
      (set out (.. out (text-style ctx footer chunk)))
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

(fn draw-right [ctx right]
  (when right
    (let [right (right-text right ctx.cols)
          col (right-col ctx.cols right)]
      (io.write ansi.esc "[" ctx.rows ";" col "H")
      (io.write (theme.color ctx.theme :muted symbols.line.vertical) " ")
      (io.write right))))

(fn draw [ctx footer]
  (terminal.cursor ctx.rows 1)
  (terminal.clear-line)
  (when footer
    (let [right footer.right
          width (left-width ctx.cols right)
          left (when footer.text (ansi.truncate footer.text width))]
      (when left
        (terminal.cursor ctx.rows 1)
        (io.write (styled-text ctx footer left)))
      (draw-right ctx right))))

{: draw
 : left-width
 : right-col
 : right-text
 : rule-cols
 : styled-text
 : text-style}
