(local faith (require :faith))
(local text-window (require :tui.text-window))
(local text (require :tui.text))

(fn test-truncate-preserves-utf8-glyphs []
  (faith.= "a │..." (text-window.truncate "a │ b c" 6)))

(fn test-crop-preserves-style-context []
  (let [cropped (text-window.crop "\27[32mabcdef\27[0m" 2 3 "\27[0m")]
    (faith.= "cde" (text.strip-ansi cropped))
    (faith.is (cropped:find "\27[32m" 1 true))))

(fn test-window-slices-visible-columns-without-inline-indicators []
  (faith.= "cdef" (text-window.window "abcdef" 2 4)))

(fn test-window-preserves-ansi-sequences-before-visible-offset []
  (let [view (text-window.window "\27[32mabcdef\27[0m" 2 3 "\27[0m")]
    (faith.= "cde" (text.strip-ansi view))
    (faith.is (view:find "\27[32m" 1 true))))

{: test-crop-preserves-style-context
 : test-truncate-preserves-utf8-glyphs
 : test-window-preserves-ansi-sequences-before-visible-offset
 : test-window-slices-visible-columns-without-inline-indicators}
