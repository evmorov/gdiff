(local faith (require :faith))
(local footer-layout (require :tui.components.footer-layout))

(fn test-right-text-reserves-separator-space []
  (faith.= "abcdef..." (footer-layout.right-text "abcdefghijk" 11)))

(fn test-right-col-places-text-at-far-right []
  (faith.= 8 (footer-layout.right-col 20 "11 chars ok")))

(fn test-left-width-reserves-right-text-and-separator []
  (faith.= 6 (footer-layout.left-width 20 "11 chars ok")))

(fn test-rule-cols-includes-left-and-right-separators []
  (let [cols (footer-layout.rule-cols 30 "left │ prompt" "65 files │ 12/65")]
    (faith.= true (. cols 6))
    (faith.= true (. cols 13))
    (faith.= true (. cols 24))))

{: test-left-width-reserves-right-text-and-separator
 : test-right-col-places-text-at-far-right
 : test-right-text-reserves-separator-space
 : test-rule-cols-includes-left-and-right-separators}
