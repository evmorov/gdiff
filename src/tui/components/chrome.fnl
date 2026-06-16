(local footer (require :tui.components.footer))
(local header (require :tui.components.header))
(local nodes (require :tui.nodes))
(local rule (require :tui.components.rule))
(local split (require :tui.components.split))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

(fn split-divider-col [body cols]
  (when (and body (= body.type :split))
    (let [(_ _ divider-col) (split.widths cols body.ratio)]
      divider-col)))

(fn view-body [view]
  (or view.body
      (when view.preview
        (nodes.split (nodes.list view.rows) (nodes.lines view.preview)
                     view.split_ratio))))

(fn header-rule [header cols ?divider-col]
  (header.rule-line header cols ?divider-col))

(fn bottom-rule [cols ?divider-col ?footer-cols]
  (rule.horizontal cols (when ?divider-col {?divider-col true}) ?footer-cols))

(fn legacy-footer [view]
  (if view.prompt (nodes.footer :notice view.prompt)
      view.warning (nodes.footer :warning view.warning)
      (nodes.footer :notice view.notice)))

(fn view-footer [view]
  (or view.footer (legacy-footer view)))

(fn footer-right-col [cols right]
  (footer.right-col cols right))

(fn footer-rule-cols [cols left right]
  (footer.rule-cols cols left right))

(fn draw-header [ctx view]
  (header.draw ctx view.header (split-divider-col (view-body view) ctx.cols)))

(fn draw-bottom-rule [ctx view]
  (let [footer-node (view-footer view)
        divider-col (split-divider-col (view-body view) ctx.cols)
        footer-cols (footer-rule-cols ctx.cols
                                      (and footer-node footer-node.text)
                                      (and footer-node footer-node.right))]
    (terminal.cursor (- ctx.rows 1) 1)
    (terminal.clear-line)
    (io.write (theme.color ctx.theme :muted
                           (bottom-rule ctx.cols divider-col footer-cols)))))

(fn styled-footer-text [ctx footer-node text]
  (footer.styled-text ctx footer-node text))

(fn draw-footer [ctx view]
  (footer.draw ctx (view-footer view)))

{: bottom-rule
 : draw-bottom-rule
 : draw-footer
 : draw-header
 : footer-rule-cols
 : footer-right-col
 : header-rule
 : legacy-footer
 : styled-footer-text}
