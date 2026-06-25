(local faith (require :faith))
(local layout (require :tui.components.chrome-layout))
(local tui (require :tui.core))

(fn test-body-accepts-modern-or-legacy-view-shapes []
  (let [body (tui.split (tui.list []) (tui.lines []) 0.5)]
    (faith.= body (layout.body {: body}))
    (faith.= :split (. (layout.body {:rows [] :preview [] :split_ratio 0.4})
                       :type))))

(fn test-footer-node-accepts-modern-or-legacy-view-shapes []
  (let [footer (tui.footer :notice "new")]
    (faith.= footer (layout.footer-node {: footer}))
    (faith.= {:type :notice :text "prompt" :right nil}
             (layout.footer-node {:prompt "prompt"}))
    (faith.= {:type :warning :text "warn" :right nil}
             (layout.footer-node {:warning "warn"}))))

(fn test-bottom-line-connects-body-and-footer-columns []
  (let [body (tui.split (tui.list []) (tui.lines [] nil 0 4) 0.4)
        footer (tui.footer :notice nil "65 files │ 12/65")
        line (layout.bottom-line {: body : footer} 30)]
    (faith.= "───────────┴▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀───"
             line)))

(fn test-bottom-line-connects-inner-split-dividers []
  (let [body (tui.split (tui.list []) (tui.lines [] nil nil nil nil [3]) 0.4)
        line (layout.bottom-line {: body} 30)]
    (faith.= "───────────┴──┴───────────────"
             line)))

{: test-body-accepts-modern-or-legacy-view-shapes
 : test-bottom-line-connects-body-and-footer-columns
 : test-bottom-line-connects-inner-split-dividers
 : test-footer-node-accepts-modern-or-legacy-view-shapes}
