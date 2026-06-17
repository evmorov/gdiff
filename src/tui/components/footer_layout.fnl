(local ansi (require :tui.ansi))
(local rule (require :tui.components.rule))

(fn right-text [right cols]
  (when right
    (ansi.truncate right (math.max 0 (- cols 2)))))

(fn right-col [cols right]
  (when right
    (let [right (right-text right cols)]
      (math.max 1 (- cols (ansi.visible-length right) 1)))))

(fn left-width [cols right]
  (if right
      (math.max 0 (- cols (ansi.visible-length (right-text right cols)) 3))
      cols))

(fn merge-cols [target cols]
  (each [col _ (pairs (or cols {}))]
    (tset target col true))
  target)

(fn rule-cols [cols left right]
  (when (or left right)
    (let [cols* {}
          left (when left (ansi.truncate left (left-width cols right)))
          right (right-text right cols)
          right-col* (right-col cols right)]
      (merge-cols cols* (rule.separator-cols left 1))
      (when right-col*
        (tset cols* right-col* true)
        (merge-cols cols* (rule.separator-cols right (+ right-col* 2))))
      cols*)))

{: left-width : right-col : right-text : rule-cols}
