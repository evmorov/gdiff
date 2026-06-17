(local faith (require :faith))
(local footer-layout (require :tui.components.footer_layout))

(fn test-right_text_reserves_separator_space []
  (faith.= "abcdef..." (footer-layout.right-text "abcdefghijk" 11)))

(fn test-right_col_places_text_at_far_right []
  (faith.= 8 (footer-layout.right-col 20 "11 chars ok")))

(fn test-left_width_reserves_right_text_and_separator []
  (faith.= 6 (footer-layout.left-width 20 "11 chars ok")))

(fn test-rule_cols_includes_left_and_right_separators []
  (let [cols (footer-layout.rule-cols 30 "left │ prompt" "65 files │ 12/65")]
    (faith.= true (. cols 6))
    (faith.= true (. cols 13))
    (faith.= true (. cols 24))))

{: test-left_width_reserves_right_text_and_separator
 : test-right_col_places_text_at_far_right
 : test-right_text_reserves_separator_space
 : test-rule_cols_includes_left_and_right_separators}
