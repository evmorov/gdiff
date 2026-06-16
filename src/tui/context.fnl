(local theme-store (require :tui.theme))

(fn new [rows cols ?theme]
  {:rows rows :cols cols :theme (or ?theme theme-store.default)})

(fn body-rows [ctx]
  (math.max 1 (- ctx.rows 3)))

{: body-rows : new}
