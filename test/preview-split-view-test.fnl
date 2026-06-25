(local faith (require :faith))
(local view (require :app.view.preview-split))

(fn all-one? [map]
  (accumulate [ok true _ src (ipairs map)]
    (and ok (= src 1))))

(fn test-wrap-rows-keeps-short-rows-as-a-single-visual-row []
  (let [(display map) (view.wrap-rows [{:kind :change :old "a" :new "b"}] 10 10
                                      21)]
    (faith.= [{:kind :change :old "a" :new "b"}] display)
    (faith.= [1] map)))

(fn test-wrap-rows-splits-long-side-and-pads-shorter []
  (let [(display map) (view.wrap-rows [{:kind :change
                                        :old "ab"
                                        :new "abcdefgh"}]
                                      3 3 7)]
    (faith.= (length map) (length display))
    (faith.is (< 1 (length display)))
    (faith.= "ab" (. (. display 1) :old))
    (faith.= nil (. (. display 2) :old))
    (faith.is (all-one? map))))

(fn test-wrap-rows-wraps-full-width-rows-across-content []
  (let [(display map) (view.wrap-rows [{:kind :hunk
                                        :old "@@ a long hunk header @@"
                                        :new "@@ a long hunk header @@"}]
                                      2 2 6)]
    (faith.is (< 1 (length display)))
    (faith.= (. (. display 1) :old) (. (. display 1) :new))
    (faith.is (all-one? map))))

{: test-wrap-rows-keeps-short-rows-as-a-single-visual-row
 : test-wrap-rows-splits-long-side-and-pads-shorter
 : test-wrap-rows-wraps-full-width-rows-across-content}
