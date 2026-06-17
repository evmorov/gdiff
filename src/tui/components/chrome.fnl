(local footer (require :tui.components.footer))
(local header (require :tui.components.header))
(local hscroll (require :tui.components.hscroll))
(local layout (require :tui.layout))
(local nodes (require :tui.nodes))
(local rule (require :tui.components.rule))
(local split (require :tui.components.split))
(local surface (require :tui.surface))
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

(fn horizontal-scrollbars [line body cols _body-rows]
  (if (and body (= body.type :split))
      (let [(_left-cols right-cols divider-col) (split.widths cols body.ratio)
            right-scroll? (not (= nil body.right.scroll))
            right-width (if right-scroll? (- right-cols 1) right-cols)]
        (hscroll.thumb line (+ divider-col 1) right-width body.right.x-scroll
                       body.right.x-max-scroll))
      line))

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
        bottom-region (layout.region ctx :bottom-rule)
        body (view-body view)
        divider-col (split-divider-col body ctx.cols)
        footer-cols (footer-rule-cols ctx.cols
                                      (and footer-node footer-node.text)
                                      (and footer-node footer-node.right))
        line (horizontal-scrollbars (bottom-rule bottom-region.cols divider-col
                                                 footer-cols)
                                    body ctx.cols (layout.body-rows ctx))]
    (surface.write-row bottom-region.row (theme.color ctx.theme :muted line)
                       false)))

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
 : horizontal-scrollbars
 : legacy-footer
 : styled-footer-text}
