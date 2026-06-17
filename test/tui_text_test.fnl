(local faith (require :faith))
(local text (require :tui.text))

(fn test-visible-length-ignores_ansi_sequences []
  (faith.= 3 (text.visible-length "\27[32mabc\27[0m")))

(fn test-visible-length-counts_utf8_glyph_as_one_cell []
  (faith.= 1 (text.visible-length "│"))
  (faith.= 5 (text.visible-length "a │ b")))

(fn test-strip-ansi_preserves_utf8_text []
  (faith.= "a │ b" (text.strip-ansi "\27[32ma │ b\27[0m")))

(fn test-next-char_preserves_whole_utf8_glyph []
  (let [(ch next-i) (text.next-char "│x" 1)]
    (faith.= "│" ch)
    (faith.= 4 next-i)))

{: test-next-char_preserves_whole_utf8_glyph
 : test-strip-ansi_preserves_utf8_text
 : test-visible-length-counts_utf8_glyph_as_one_cell
 : test-visible-length-ignores_ansi_sequences}
