(local txt (require :tui.text))
(local text-highlight (require :tui.text-highlight))
(local text-window (require :tui.text-window))

(local esc txt.esc)
(local nl "\r\n")

(local reset-style "\27[0m")
(local next-char txt.next-char)
(local pad-right txt.pad-right)
(local strip-ansi txt.strip-ansi)
(local visible-length txt.visible-length)

(fn color? []
  (not (os.getenv "NO_COLOR")))

(fn reset-code []
  (if (color?) reset-style ""))

(fn apply-style [style text]
  (if (and (color?) style)
      (.. style text reset-style)
      text))

(fn restyle-after-resets [text style]
  (if (and (color?) style)
      (text:gsub (txt.pattern-quote reset-style) (.. reset-style style))
      text))

(fn apply-block-style [style text]
  (if (and (color?) style)
      (.. style (restyle-after-resets text style) reset-style)
      text))

(fn highlight-matches [s query start-code end-code]
  (if (color?)
      (text-highlight.highlight s query start-code (or end-code reset-style))
      (tostring (or s ""))))

(fn truncate [s width]
  (text-window.truncate s width (reset-code)))

(fn crop [s offset width]
  (text-window.crop s offset width (reset-code)))

(fn window [s offset width]
  (text-window.window s offset width (reset-code)))

{: apply-block-style
 : apply-style
 : color?
 : crop
 : esc
 : highlight-matches
 : nl
 : next-char
 : pad-right
 : reset-code
 : reset-style
 : strip-ansi
 : truncate
 : visible-length
 : window}
