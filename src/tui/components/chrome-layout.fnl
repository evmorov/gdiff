(local footer (require :tui.components.footer))
(local hscroll (require :tui.components.hscroll))
(local nodes (require :tui.nodes))
(local rule (require :tui.components.rule))
(local split (require :tui.components.split))

(fn body [view]
  (or view.body
      (when view.preview
        (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                     view.split_ratio))))

(fn legacy-footer [view]
  (if view.prompt (nodes.footer :notice view.prompt)
      view.warning (nodes.footer :warning view.warning)
      (nodes.footer :notice view.notice)))

(fn footer-node [view]
  (or view.footer (legacy-footer view)))

(fn split-divider-col [body cols]
  (when (and body (= body.type :split))
    (let [(_ _ divider-col) (split.widths cols body.ratio)]
      divider-col)))

(fn footer-rule-cols [cols footer-node]
  (footer.rule-cols cols (and footer-node footer-node.text)
                    (and footer-node footer-node.right)))

(fn bottom-rule [cols ?divider-col ?footer-cols]
  (rule.horizontal cols (when ?divider-col {?divider-col true}) ?footer-cols))

(fn horizontal-scrollbars [line body cols]
  (if (and body (= body.type :split))
      (let [(_left-cols right-cols divider-col) (split.widths cols body.ratio)
            right-scroll? (not (= nil body.right.scroll))
            right-width (if right-scroll? (- right-cols 1) right-cols)]
        (hscroll.thumb line (+ divider-col 1) right-width body.right.x-scroll
                       body.right.x-max-scroll))
      line))

(fn bottom-line [view cols]
  (let [body (body view)
        footer-node (footer-node view)
        divider-col (split-divider-col body cols)
        footer-cols (footer-rule-cols cols footer-node)]
    (horizontal-scrollbars (bottom-rule cols divider-col footer-cols) body cols)))

{: body
 : bottom-line
 : bottom-rule
 : footer-node
 : footer-rule-cols
 : horizontal-scrollbars
 : legacy-footer
 : split-divider-col}
