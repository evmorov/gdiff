(local faith (require :faith))
(local ansi (require :tui.ansi))
(local footer-text (require :tui.components.footer-text))
(local tui (require :tui.core))

(fn test-styled-text-keeps-plain-text-visible []
  (let [ctx (tui.context 10 80)
        footer (tui.footer :prompt "Search │ next")
        styled (footer-text.styled ctx footer footer.text)]
    (faith.= "Search │ next" (ansi.strip-ansi styled))))

(fn test-text-style-uses-warning-role []
  (let [ctx (tui.context 10 80)
        footer (tui.footer :warning "warn")
        styled (footer-text.text-style ctx footer "warn")]
    (faith.= "warn" (ansi.strip-ansi styled))))

{: test-styled-text-keeps-plain-text-visible
 : test-text-style-uses-warning-role}
