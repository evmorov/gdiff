(local faith (require :faith))
(local nav (require :app.search-nav))

(local matches [{:entry 2} {:entry 5} {:entry 8}])

(local mixed [{:entry 2} {:row 2 :line 3} {:row 2 :line 7} {:entry 5}])

(fn test-first-at-or-after-starts-at-cursor []
  (faith.= 1 (nav.first-at-or-after {:row 1} matches))
  (faith.= 2 (nav.first-at-or-after {:row 5} matches))
  (faith.= 1 (nav.first-at-or-after {:row 9} matches)))

(fn test-first-after-is-relative-to-cursor-and-wraps []
  (faith.= 1 (nav.first-after {:row 1} matches))
  (faith.= 2 (nav.first-after {:row 2} matches))
  (faith.= 1 (nav.first-after {:row 8} matches)))

(fn test-last-before-is-relative-to-cursor-and-wraps []
  (faith.= 3 (nav.last-before {:row 1} matches))
  (faith.= 1 (nav.last-before {:row 5} matches))
  (faith.= 2 (nav.last-before {:row 8} matches)))

(fn test-file-row-comes-before-its-lines []
  (faith.= 2 (nav.first-after {:row 2} mixed))
  (faith.= 3 (nav.first-after {:row 2 :line 3} mixed))
  (faith.= 4 (nav.first-after {:row 2 :line 7} mixed))
  (faith.= 3 (nav.last-before {:row 5} mixed))
  (faith.= 1 (nav.last-before {:row 2 :line 3} mixed))
  (faith.= 2 (nav.first-at-or-after {:row 2 :line 1} mixed)))

(fn test-index-of-finds-the-match-at-the-same-place []
  (faith.= 3 (nav.index-of mixed {:row 2 :line 7 :side :new}))
  (faith.= 1 (nav.index-of mixed {:entry 2}))
  (faith.= nil (nav.index-of mixed {:row 9 :line 1})))

(fn test-row-of-prefers-tree-row []
  (faith.= 4 (nav.row-of {:entry 10 :tree-row 4}))
  (faith.= 6 (nav.row-of {:row 6 :line 2})))

{: test-first-after-is-relative-to-cursor-and-wraps
 : test-first-at-or-after-starts-at-cursor
 : test-last-before-is-relative-to-cursor-and-wraps
 : test-file-row-comes-before-its-lines
 : test-index-of-finds-the-match-at-the-same-place
 : test-row-of-prefers-tree-row}
