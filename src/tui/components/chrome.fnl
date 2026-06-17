(local footer (require :tui.components.footer))
(local header (require :tui.components.header))
(local layout (require :tui.layout))
(local nodes (require :tui.nodes))
(local rule (require :tui.components.rule))
(local scrollbar (require :tui.components.scrollbar))
(local split (require :tui.components.split))
(local surface (require :tui.surface))
(local symbols (require :tui.symbols))
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

(fn horizontal-scroll [x-scroll x-max-scroll visible]
  (when (and (< 0 (or x-max-scroll 0)) (< 0 visible))
    {:offset (or x-scroll 0) :visible visible :total (+ visible x-max-scroll)}))

(fn draw-horizontal-thumb [ctx row start-col width x-scroll x-max-scroll]
  (let [scroll (horizontal-scroll x-scroll x-max-scroll width)]
    (when (scrollbar.visible? scroll width)
      (for [col 1 width]
        (let [mark (scrollbar.marker scroll width col
                                     symbols.line.horizontal-scroll-thumb)]
          (when mark
            (surface.write-at row (+ start-col col -1)
                              (theme.color ctx.theme :muted mark))))))))

(fn draw-horizontal-scrollbars [ctx body bottom-row]
  (when (and body (= body.type :split))
    (let [(_left-cols right-cols divider-col) (split.widths ctx.cols body.ratio)
          body-rows (layout.body-rows ctx)
          right-scroll? (scrollbar.visible? body.right.scroll body-rows)
          right-width (if right-scroll? (- right-cols 1) right-cols)]
      (draw-horizontal-thumb ctx bottom-row (+ divider-col 1) right-width
                             body.right.x-scroll body.right.x-max-scroll))))

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
                                      (and footer-node footer-node.right))]
    (surface.write-row bottom-region.row
                       (theme.color ctx.theme :muted
                                    (bottom-rule bottom-region.cols divider-col
                                                 footer-cols))
                       true)
    (draw-horizontal-scrollbars ctx body bottom-region.row)))

(fn styled-footer-text [ctx footer-node text]
  (footer.styled-text ctx footer-node text))

(fn draw-footer [ctx view]
  (footer.draw ctx (view-footer view)))

{: bottom-rule
 : draw-bottom-rule
 : draw-footer
 : draw-header
 : draw-horizontal-scrollbars
 : footer-rule-cols
 : footer-right-col
 : header-rule
 : horizontal-scroll
 : legacy-footer
 : styled-footer-text}
