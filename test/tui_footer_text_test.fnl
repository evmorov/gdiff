(local faith (require :faith))
(local ansi (require :tui.ansi))
(local footer-text (require :tui.components.footer_text))
(local tui (require :tui.core))

(fn test-styled_text_keeps_plain_text_visible []
  (let [ctx (tui.context 10 80)
        footer (tui.footer :prompt "Search │ next")
        styled (footer-text.styled ctx footer footer.text)]
    (faith.= "Search │ next" (ansi.strip-ansi styled))))

(fn test-text_style_uses_warning_role []
  (let [ctx (tui.context 10 80)
        footer (tui.footer :warning "warn")
        styled (footer-text.text-style ctx footer "warn")]
    (faith.= "warn" (ansi.strip-ansi styled))))

{: test-styled_text_keeps_plain_text_visible
 : test-text_style_uses_warning_role}
