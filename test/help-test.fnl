(local faith (require :faith))
(local help (require :app.view.help))
(local theme (require :tui.theme))
(local tui (require :tui.core))

(fn state [?cols]
  {:theme (theme.new nil) :term_cols ?cols})

(fn block [height]
  (fcollect [i 1 height] (.. "line" i)))

(fn test-render-group-starts-with-the-heading []
  (let [lines (help.render-group (state)
                                 {:title "Common" :items [["q" "Quit"]]})]
    (faith.= 2 (length lines))
    (faith.is (string.find (tui.strip-ansi (. lines 1)) "Common"))
    (faith.is (string.find (tui.strip-ansi (. lines 2)) "Quit"))))

(fn test-distribute-balances-blocks-in-order []
  (let [cols (help.distribute [(block 3) (block 3) (block 2)] 2)]
    (faith.= 2 (length cols))
    (faith.= 1 (length (. cols 1)))
    (faith.= 2 (length (. cols 2)))))

(fn test-distribute-keeps-everything-in-one-column []
  (let [cols (help.distribute [(block 3) (block 2)] 1)]
    (faith.= 1 (length cols))
    (faith.= 2 (length (. cols 1)))))

(fn test-choose-columns-uses-one-column-when-narrow []
  (let [blocks (icollect [_ g (ipairs help.groups)]
                 (help.render-group (state) g))]
    (faith.= 1 (help.choose-columns blocks 20))))

(fn test-choose-columns-spreads-groups-when-wide []
  (let [blocks (icollect [_ g (ipairs help.groups)]
                 (help.render-group (state) g))]
    (faith.= (length help.groups) (help.choose-columns blocks 999))))

(fn test-join-columns-pads-inner-columns-to-width []
  (let [columns [{:lines ["ab" "c"] :width 2} {:lines ["xyz"] :width 3}]
        rows (help.join-columns columns)]
    (faith.= 2 (length rows))
    (faith.= "ab   xyz" (. rows 1))
    (faith.= "c    " (. rows 2))))

(fn test-lines-render-every-shortcut []
  (let [text (table.concat (icollect [_ l (ipairs (help.lines (state 999)))]
                             (tui.strip-ansi l))
                           "\n")]
    (each [_ group (ipairs help.groups)]
      (faith.is (string.find text group.title 1 true))
      (each [_ [_keys label] (ipairs group.items)]
        (faith.is (string.find text label 1 true))))))

{: test-render-group-starts-with-the-heading
 : test-distribute-balances-blocks-in-order
 : test-distribute-keeps-everything-in-one-column
 : test-choose-columns-uses-one-column-when-narrow
 : test-choose-columns-spreads-groups-when-wide
 : test-join-columns-pads-inner-columns-to-width
 : test-lines-render-every-shortcut}
