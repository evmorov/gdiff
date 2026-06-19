(local faith (require :faith))
(local layout (require :tui.components.chrome_layout))
(local tui (require :tui.core))

(fn test-body_accepts_modern_or_legacy_view_shapes []
  (let [body (tui.split (tui.list []) (tui.lines []) 0.5)]
    (faith.= body (layout.body {: body}))
    (faith.= :split (. (layout.body {:rows [] :preview [] :split_ratio 0.4})
                       :type))))

(fn test-footer_node_accepts_modern_or_legacy_view_shapes []
  (let [footer (tui.footer :notice "new")]
    (faith.= footer (layout.footer-node {: footer}))
    (faith.= {:type :notice :text "prompt" :right nil}
             (layout.footer-node {:prompt "prompt"}))
    (faith.= {:type :warning :text "warn" :right nil}
             (layout.footer-node {:warning "warn"}))))

(fn test-bottom_line_connects_body_and_footer_columns []
  (let [body (tui.split (tui.list []) (tui.lines [] nil 0 4) 0.4)
        footer (tui.footer :notice nil "65 files │ 12/65")
        line (layout.bottom-line {: body : footer} 30)]
    (faith.= "───────────┴▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀───"
             line)))

{: test-body_accepts_modern_or_legacy_view_shapes
 : test-bottom_line_connects_body_and_footer_columns
 : test-footer_node_accepts_modern_or_legacy_view_shapes}
