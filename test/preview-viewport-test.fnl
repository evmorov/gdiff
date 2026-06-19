(local faith (require :faith))
(local viewport (require :preview.viewport))

(fn state []
  {:split_ratio 0.5 :preview_wrap? false :preview_scroll 0})

(fn test-scroll-state-clamps-offset-to-visible-content []
  (faith.= {:offset 0 :total 3 :visible 5}
           (viewport.scroll-state ["a" "b" "c"] 5 10))
  (faith.= {:offset 2 :total 5 :visible 3}
           (viewport.scroll-state ["a" "b" "c" "d" "e"] 3 99)))

(fn test-visible-lines-uses-scroll-state-without-mutating-state []
  (let [lines ["a" "b" "c" "d"]
        scroll-state (viewport.scroll-state lines 2 1)]
    (faith.= ["b" "c"] (viewport.visible-lines lines scroll-state))))

(fn test-lines-for-width-wraps-without-updating-preview-fields []
  (let [state (state)]
    (set state.preview_wrap? true)
    (let [lines (viewport.lines-for-width state ["abcdefghij"] 2 10)]
      (faith.= ["abc↪" "def↪" "ghij"] lines)
      (faith.= nil state.preview_total)
      (faith.= 0 state.preview_scroll))))

{: test-lines-for-width-wraps-without-updating-preview-fields
 : test-scroll-state-clamps-offset-to-visible-content
 : test-visible-lines-uses-scroll-state-without-mutating-state}
