(local ansi (require :tui.ansi))
(local symbols (require :tui.symbols))

(fn col? [?cols col]
  (if (= (type ?cols) :table)
      (. ?cols col)
      (= col ?cols)))

(fn symbol [col ?up-cols ?down-cols]
  (let [up? (col? ?up-cols col)
        down? (col? ?down-cols col)]
    (if (and up? down?) symbols.line.join-cross
        up? symbols.line.join-up
        down? symbols.line.join-down
        symbols.line.horizontal)))

(fn horizontal [cols ?up-cols ?down-cols]
  (var out "")
  (for [col 1 cols]
    (set out (.. out (symbol col ?up-cols ?down-cols))))
  out)

(fn separator-cols [text start-col]
  (let [cols {}]
    (when text
      (let [plain (ansi.strip-ansi text)]
        (var i 1)
        (var visible 1)
        (while (<= i (length plain))
          (let [(ch next-i) (ansi.next-char plain i)]
            (when (= ch symbols.line.separator)
              (tset cols (+ start-col visible -1) true))
            (set visible (+ visible 1))
            (set i next-i)))))
    cols))

{: horizontal : separator-cols : symbol}
