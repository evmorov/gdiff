(local faith (require :faith))
(local text (require :tui.text))

(fn test-visible-length-ignores-ansi-sequences []
  (faith.= 3 (text.visible-length "\27[32mabc\27[0m")))

(fn test-byte-helpers-name-ascii-and-ansi-checks []
  (faith.= 27 text.esc-byte)
  (faith.= 91 text.left-bracket-byte)
  (faith.= 128 text.ascii-limit)
  (faith.= true (text.ascii-byte? (string.byte "a")))
  (faith.= false (text.ascii-byte? 226))
  (faith.= true (text.ansi-sequence? "\27[32m" 1)))

(fn test-visible-length-counts-utf8-glyph-as-one-cell []
  (faith.= 1 (text.visible-length "│"))
  (faith.= 5 (text.visible-length "a │ b")))

(fn test-visible-length-counts-styled-utf8-text-by-cell []
  (faith.= 5 (text.visible-length "\27[32ma \27[1m│\27[0m b\27[0m"))
  (faith.= 0 (text.visible-length "\27[0m"))
  (faith.= 4 (text.visible-length "\27[38;2;10;20;30mabcd")))

(fn test-visible-length-counts-invalid-utf8-bytes-as-cells []
  (faith.= 2 (text.visible-length "a\200"))
  (faith.= 1 (text.visible-length "\27[32m\255\27[0m")))

(fn test-strip-ansi-preserves-utf8-text []
  (faith.= "a │ b" (text.strip-ansi "\27[32ma │ b\27[0m")))

(fn test-next-char-preserves-whole-utf8-glyph []
  (let [(ch next-i) (text.next-char "│x" 1)]
    (faith.= "│" ch)
    (faith.= 4 next-i)))

{: test-next-char-preserves-whole-utf8-glyph
 : test-byte-helpers-name-ascii-and-ansi-checks
 : test-strip-ansi-preserves-utf8-text
 : test-visible-length-counts-invalid-utf8-bytes-as-cells
 : test-visible-length-counts-styled-utf8-text-by-cell
 : test-visible-length-counts-utf8-glyph-as-one-cell
 : test-visible-length-ignores-ansi-sequences}
