(local layout (require :tui.layout))
(local theme-store (require :tui.theme))

(fn new [rows cols ?theme]
  {: rows : cols :theme (or ?theme theme-store.default)})

(fn body-rows [ctx]
  (layout.body-rows ctx))

{: body-rows : new}
