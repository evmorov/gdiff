(local faith (require :faith))
(local line-selection (require :app.line-selection))

(local lines ["alpha" "beta" "gamma" "delta"])

(fn test-range-without-anchor-is-just-the-cursor []
  (let [(lo hi) (line-selection.range nil 3)]
    (faith.= 3 lo)
    (faith.= 3 hi)))

(fn test-range-orders-anchor-and-cursor []
  (let [(lo hi) (line-selection.range 4 2)]
    (faith.= 2 lo)
    (faith.= 4 hi)))

(fn test-selected-text-joins-cursor-line-only []
  (faith.= "gamma" (line-selection.selected-text lines nil 3)))

(fn test-selected-text-joins-the-selected-range []
  (faith.= "beta\ngamma\ndelta" (line-selection.selected-text lines 4 2)))

(fn test-selected-text-clamps-to-available-lines []
  (faith.= "delta" (line-selection.selected-text lines 4 9)))

(fn test-line-count-matches-the-clamped-range []
  (faith.= 1 (line-selection.line-count lines nil 2))
  (faith.= 3 (line-selection.line-count lines 4 2))
  (faith.= 1 (line-selection.line-count lines 4 9)))

;; Two display rows ("foo↪" + "bar") wrap one logical line "foobar"; "baz" is a
;; second logical line on the third display row.
(local wrapped-display ["foo↪" "bar" "baz"])
(local wrapped-source ["foobar" "baz"])
(local wrapped-map [1 1 2])

(fn test-selected-text-yanks-one-line-for-a-wrapped-selection []
  (faith.= "foobar"
           (line-selection.selected-text wrapped-display 1 2 wrapped-source
                                         wrapped-map)))

(fn test-selected-text-on-a-wrapped-fragment-yanks-the-whole-line []
  (faith.= "foobar"
           (line-selection.selected-text wrapped-display nil 2 wrapped-source
                                         wrapped-map)))

(fn test-selected-text-spanning-two-wrapped-lines []
  (faith.= "foobar\nbaz"
           (line-selection.selected-text wrapped-display 1 3 wrapped-source
                                         wrapped-map)))

(fn test-line-count-counts-source-lines-not-display-rows []
  (faith.= 1 (line-selection.line-count wrapped-display 1 2 wrapped-map))
  (faith.= 2 (line-selection.line-count wrapped-display 1 3 wrapped-map)))

(fn test-start-and-stop-track-the-cursor []
  (let [state {:preview_cursor 5}]
    (faith.= false (line-selection.active? state))
    (line-selection.start state)
    (faith.= true (line-selection.active? state))
    (faith.= 5 state.preview_selection_anchor)
    (line-selection.stop state)
    (faith.= false (line-selection.active? state))))

{: test-range-without-anchor-is-just-the-cursor
 : test-range-orders-anchor-and-cursor
 : test-selected-text-joins-cursor-line-only
 : test-selected-text-joins-the-selected-range
 : test-selected-text-clamps-to-available-lines
 : test-line-count-matches-the-clamped-range
 : test-selected-text-yanks-one-line-for-a-wrapped-selection
 : test-selected-text-on-a-wrapped-fragment-yanks-the-whole-line
 : test-selected-text-spanning-two-wrapped-lines
 : test-line-count-counts-source-lines-not-display-rows
 : test-start-and-stop-track-the-cursor}
