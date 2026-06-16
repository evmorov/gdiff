(local ansi (require :tui.ansi))
(local context (require :tui.context))
(local draw (require :tui.draw))
(local body (require :tui.components.body))
(local chrome (require :tui.components.chrome))
(local footer-view (require :tui.components.footer))
(local frame (require :tui.frame))
(local header-view (require :tui.components.header))
(local lines-view (require :tui.components.lines))
(local list-view (require :tui.components.list))
(local nodes (require :tui.nodes))
(local renderer (require :tui.renderer))
(local rule-view (require :tui.components.rule))
(local row-view (require :tui.components.row))
(local runtime (require :tui.runtime))
(local scrollbar (require :tui.components.scrollbar))
(local split-view (require :tui.components.split))
(local terminal (require :tui.terminal))
(local theme (require :tui.theme))

{:color theme.color
 :components {:body body
              :chrome chrome
              :footer footer-view
              :header header-view
              :lines lines-view
              :list list-view
              :rule rule-view
              :row row-view
              :scrollbar scrollbar
              :split split-view}
 :context context.new
 :context-body-rows context.body-rows
 :default-theme theme.default
 :draw draw.draw
 :footer nodes.footer
 :frame frame
 :highlight-matches theme.highlight-matches
 :lines nodes.lines
 :list nodes.list
 :read-key terminal.read-key
 :renderer renderer
 :row nodes.row
 :run runtime.run
 :run-loop runtime.run-loop
 :screen nodes.screen
 :split nodes.split
 :strip-ansi ansi.strip-ansi
 :suspend terminal.suspend
 :terminal-size terminal.terminal-size
 :theme theme.new
 :truncate ansi.truncate}
