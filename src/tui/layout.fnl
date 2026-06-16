(fn rect [row col rows cols]
  {:row row :col col :rows rows :cols cols})

(fn screen [rows cols]
  {:header (rect 1 1 1 cols)
   :header-rule (rect 2 1 1 cols)
   :body (rect 3 1 (math.max 1 (- rows 4)) cols)
   :bottom-rule (rect (- rows 1) 1 1 cols)
   :footer (rect rows 1 1 cols)})

(fn for-context [ctx]
  (screen ctx.rows ctx.cols))

(fn region [ctx name]
  (. (for-context ctx) name))

(fn body [ctx]
  (region ctx :body))

(fn body-rows [ctx]
  (. (body ctx) :rows))

(fn row [rect index]
  (+ rect.row index -1))

{: body : body-rows : for-context : rect : region : row : screen}
