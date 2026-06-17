(local faith (require :faith))
(local text-window (require :tui.text_window))
(local text (require :tui.text))

(fn test-truncate_preserves_utf8_glyphs []
  (faith.= "a │..." (text-window.truncate "a │ b c" 6)))

(fn test-crop_preserves_style_context []
  (let [cropped (text-window.crop "\27[32mabcdef\27[0m" 2 3 "\27[0m")]
    (faith.= "cde" (text.strip-ansi cropped))
    (faith.is (cropped:find "\27[32m" 1 true))))

(fn test-window_slices_visible_columns_without_inline_indicators []
  (faith.= "cdef" (text-window.window "abcdef" 2 4)))

(fn test-window_preserves_ansi_sequences_before_visible_offset []
  (let [view (text-window.window "\27[32mabcdef\27[0m" 2 3 "\27[0m")]
    (faith.= "cde" (text.strip-ansi view))
    (faith.is (view:find "\27[32m" 1 true))))

{: test-crop_preserves_style_context
 : test-truncate_preserves_utf8_glyphs
 : test-window_preserves_ansi_sequences_before_visible_offset
 : test-window_slices_visible_columns_without_inline_indicators}
