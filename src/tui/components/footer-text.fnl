(local ansi (require :tui.ansi))
(local symbols (require :tui.symbols))
(local theme (require :tui.theme))

(fn text-style [ctx footer text]
  (case footer.type
    :warning (theme.color ctx.theme :warning text)
    :notice (theme.color ctx.theme :notice text)
    :prompt (theme.color ctx.theme :notice text)
    _ text))

(fn styled [ctx footer text]
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

{: styled : text-style}
