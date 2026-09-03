(local faith (require :faith))
(local line-moves (require :preview.line-moves))

(fn diff [& lines]
  (table.concat lines "\n"))

(fn test-detect-marks-a-single-line-moved-to-another-hunk []
  (let [moves (line-moves.detect (diff "@@ -9,3 +9,2 @@" " a"
                                       "-t.string \"uuid\"" " b"
                                       "@@ -39,2 +38,3 @@" " c"
                                       "+t.string \"uuid\"" " d"))]
    (faith.= {10 {:start 39 :stop 39 :first? true}} moves.old)
    (faith.= {39 {:start 10 :stop 10 :first? true}} moves.new)))

(fn test-detect-marks-a-block-with-first-only-on-its-head []
  (let [moves (line-moves.detect (diff "@@ -1,3 +0,0 @@" "-alpha one"
                                       "-beta two" "-gamma three"
                                       "@@ -0,0 +20,3 @@" "+alpha one"
                                       "+beta two" "+gamma three"))]
    (faith.= {1 {:start 20 :stop 22 :first? true}
              2 {:start 20 :stop 22}
              3 {:start 20 :stop 22}} moves.old)
    (faith.= {20 {:start 1 :stop 3 :first? true}
              21 {:start 1 :stop 3}
              22 {:start 1 :stop 3}} moves.new)))

(fn test-detect-ignores-indentation-across-hunks []
  (let [moves (line-moves.detect (diff "@@ -1,1 +0,0 @@" "-  indented line"
                                       "@@ -0,0 +30,1 @@" "+      indented line"))]
    (faith.= {1 {:start 30 :stop 30 :first? true}} moves.old)))

(fn test-detect-skips-in-place-reindentation []
  (let [moves (line-moves.detect (diff "@@ -1,2 +1,2 @@" "-  first line"
                                       "-  second line" "+    first line"
                                       "+    second line"))]
    (faith.= {} moves.old)
    (faith.= {} moves.new)))

(fn test-detect-never-matches-short-lines-alone []
  (let [moves (line-moves.detect (diff "@@ -1,1 +0,0 @@" "-end"
                                       "@@ -0,0 +30,1 @@" "+end"))]
    (faith.= {} moves.old)))

(fn test-detect-absorbs-short-neighbours-into-a-block []
  (let [moves (line-moves.detect (diff "@@ -1,2 +0,0 @@" "-def unique_method"
                                       "-end" "@@ -0,0 +30,2 @@"
                                       "+def unique_method" "+end"))]
    (faith.= {1 {:start 30 :stop 31 :first? true} 2 {:start 30 :stop 31}}
             moves.old)
    (faith.= {30 {:start 1 :stop 2 :first? true} 31 {:start 1 :stop 2}}
             moves.new)))

(fn test-detect-pairs-equal-repetitions-in-line-order []
  (let [moves (line-moves.detect (diff "@@ -1,3 +0,0 @@" "-repeated line"
                                       "-repeated line" "-repeated line"
                                       "@@ -0,0 +30,1 @@" "+repeated line"
                                       "@@ -0,0 +40,1 @@" "+repeated line"
                                       "@@ -0,0 +50,1 @@" "+repeated line"))]
    (faith.= {1 {:start 30 :stop 30 :first? true}
              2 {:start 40 :stop 40 :first? true}
              3 {:start 50 :stop 50 :first? true}} moves.old)
    (faith.= {30 {:start 1 :stop 1 :first? true}
              40 {:start 2 :stop 2 :first? true}
              50 {:start 3 :stop 3 :first? true}} moves.new)))

(fn test-detect-pairs-repeated-lines-across-tables []
  (let [moves (line-moves.detect (diff "@@ -1,4 +1,4 @@" " create_table a"
                                       "-  t.datetime \"created_at\""
                                       "   t.string \"name\""
                                       "+  t.datetime \"created_at\"" " end"
                                       "@@ -20,4 +20,4 @@" " create_table b"
                                       "-  t.datetime \"created_at\""
                                       "   t.string \"title\""
                                       "+  t.datetime \"created_at\"" " end"))]
    (faith.= {2 {:start 3 :stop 3 :first? true}
              21 {:start 22 :stop 22 :first? true}} moves.old)
    (faith.= {3 {:start 2 :stop 2 :first? true}
              22 {:start 21 :stop 21 :first? true}} moves.new)))

(fn test-detect-ignores-unequal-repetitions []
  (let [moves (line-moves.detect (diff "@@ -1,3 +0,0 @@" "-repeated line"
                                       "-repeated line" "-repeated line"
                                       "@@ -0,0 +30,2 @@" "+repeated line"
                                       "+repeated line"))]
    (faith.= {} moves.old)
    (faith.= {} moves.new)))

(fn test-detect-coalesces-repeated-blocks []
  (let [moves (line-moves.detect (diff "@@ -1,4 +0,0 @@" "-alpha one"
                                       "-beta two" "-alpha one" "-beta two"
                                       "@@ -0,0 +20,2 @@" "+alpha one"
                                       "+beta two" "@@ -0,0 +40,2 @@"
                                       "+alpha one" "+beta two"))]
    (faith.= {1 {:start 20 :stop 21 :first? true}
              2 {:start 20 :stop 21}
              3 {:start 40 :stop 41 :first? true}
              4 {:start 40 :stop 41}} moves.old)
    (faith.= {20 {:start 1 :stop 2 :first? true}
              21 {:start 1 :stop 2}
              40 {:start 3 :stop 4 :first? true}
              41 {:start 3 :stop 4}} moves.new)))

(fn test-detect-leaves-edited-lines-alone []
  (let [moves (line-moves.detect (diff "@@ -1,1 +0,0 @@" "-original text"
                                       "@@ -0,0 +30,1 @@" "+original text!"))]
    (faith.= {} moves.old)))

(fn test-detect-keeps-numbering-across-context-lines []
  (let [moves (line-moves.detect (diff "@@ -5,5 +5,5 @@" " ctx" " ctx"
                                       "-moved down" " ctx" "+moved down" " ctx"))]
    (faith.= {7 {:start 8 :stop 8 :first? true}} moves.old)
    (faith.= {8 {:start 7 :stop 7 :first? true}} moves.new)))

(fn test-annotation-describes-the-counterpart []
  (faith.= " (moved to line 19)"
           (line-moves.annotation :old {:start 19 :stop 19 :first? true}))
  (faith.= " (moved from lines 16-20)"
           (line-moves.annotation :new {:start 16 :stop 20 :first? true}))
  (faith.= "" (line-moves.annotation :old {:start 16 :stop 20}))
  (faith.= "" (line-moves.annotation :old nil)))

{: test-detect-marks-a-single-line-moved-to-another-hunk
 : test-detect-marks-a-block-with-first-only-on-its-head
 : test-detect-ignores-indentation-across-hunks
 : test-detect-skips-in-place-reindentation
 : test-detect-never-matches-short-lines-alone
 : test-detect-absorbs-short-neighbours-into-a-block
 : test-detect-pairs-equal-repetitions-in-line-order
 : test-detect-pairs-repeated-lines-across-tables
 : test-detect-ignores-unequal-repetitions
 : test-detect-coalesces-repeated-blocks
 : test-detect-leaves-edited-lines-alone
 : test-detect-keeps-numbering-across-context-lines
 : test-annotation-describes-the-counterpart}
