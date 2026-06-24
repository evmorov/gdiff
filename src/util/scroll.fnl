(local math-util (require :util.math))

(fn scrolls? [total visible]
  (> (or total 0) (or visible 0)))

(fn max-offset [total visible]
  (math.max 0 (- (or total 0) (or visible 0))))

(fn clamp-offset [offset total visible]
  (math-util.clamp (or offset 0) 0 (max-offset total visible)))

(fn info [offset total visible]
  (when (scrolls? total visible)
    {:offset (or offset 0) : total : visible}))

{: clamp-offset : info : max-offset : scrolls?}
