(local faith (require :faith))
(local nav (require :app.search_nav))

(local matches [{:entry 2} {:entry 5} {:entry 8}])

(fn test-first-at-or-after-starts_at_cursor []
  (faith.= 1 (nav.first-at-or-after 1 matches))
  (faith.= 2 (nav.first-at-or-after 5 matches))
  (faith.= 1 (nav.first-at-or-after 9 matches)))

(fn test-first-after-is_relative_to_cursor_and_wraps []
  (faith.= 1 (nav.first-after 1 matches))
  (faith.= 2 (nav.first-after 2 matches))
  (faith.= 1 (nav.first-after 8 matches)))

(fn test-last-before-is_relative_to_cursor_and_wraps []
  (faith.= 3 (nav.last-before 1 matches))
  (faith.= 1 (nav.last-before 5 matches))
  (faith.= 2 (nav.last-before 8 matches)))

(fn test-position_prefers_tree_row []
  (faith.= 4 (nav.position {:entry 10 :tree-row 4})))

{: test-first-after-is_relative_to_cursor_and_wraps
 : test-first-at-or-after-starts_at_cursor
 : test-last-before-is_relative_to_cursor_and_wraps
 : test-position_prefers_tree_row}
