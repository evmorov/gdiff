(local faith (require :faith))
(local view (require :app.view.preview-split))
(local preview-key (require :preview.key))

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

(fn test-prepare-reuses-cached-split-layout []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :context :old "x" :new "x" :old-no 1 :new-no 1}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")
        state {:revision "HEAD"
               :split_cache {key rows}
               :preview_wrap? true
               :show_numbers? false
               :split_ratio 0.5
               :preview_scroll 0
               :preview_x_scroll 0
               :full_context? false}]
    (view.prepare state 5 40 {:entry entry})
    (set state.split_display_cache.marker true)
    (view.prepare state 5 40 {:entry entry})
    (faith.= true state.split_display_cache.marker)
    (view.prepare state 5 80 {:entry entry})
    (faith.= nil state.split_display_cache.marker)))

{: test-wrap-rows-keeps-short-rows-as-a-single-visual-row
 : test-wrap-rows-splits-long-side-and-pads-shorter
 : test-wrap-rows-wraps-full-width-rows-across-content
 : test-prepare-reuses-cached-split-layout}
