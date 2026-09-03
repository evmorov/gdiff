(local faith (require :faith))
(local view (require :app.view.preview-split))
(local preview (require :preview.core))
(local preview-key (require :preview.key))
(local tui (require :tui.core))

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

(fn test-split-preview-gutter-shows-blame-next-to-numbers []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :context :old "x" :new "x" :old-no 1 :new-no 1}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")
        state {:revision "HEAD"
               :split_cache {key rows}
               :preview_wrap? true
               :show_numbers? true
               :show_blame? true
               :split_ratio 0.5
               :preview_scroll 0
               :preview_x_scroll 0
               :full_context? false}
        old-blame-lines preview.blame-lines]
    (set preview.blame-lines
         (fn [_state _entry side]
           (if (= side :old)
               {1 "29/04/2021 Evgenii"}
               {1 "30/04/2021 Ada"})))
    (view.prepare state 5 80 {:entry entry})
    (set preview.blame-lines old-blame-lines)
    (let [node (view.body state 5 80)
          text (tui.strip-ansi (. node.lines 1))]
      (faith.match "1 29/04/2021 Evgenii" text)
      (faith.match "1 30/04/2021 Ada" text))))

(fn test-split-preview-leaves-wrapped-continuation-gutter-blank []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :context
               :old "abcdefghijklmnopqrstuvwxyz"
               :new "abcdefghijklmnopqrstuvwxyz"
               :old-no 1
               :new-no 1}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")
        state {:revision "HEAD"
               :split_cache {key rows}
               :preview_wrap? true
               :show_numbers? true
               :show_blame? true
               :split_ratio 0.5
               :preview_scroll 0
               :preview_x_scroll 0
               :full_context? false}
        old-blame-lines preview.blame-lines]
    (set preview.blame-lines
         (fn [_state _entry _side]
           {1 "07/07/2026 Not"}))
    (view.prepare state 10 60 {:entry entry})
    (set preview.blame-lines old-blame-lines)
    (let [node (view.body state 10 60)
          first (tui.strip-ansi (. node.lines 1))
          second (tui.strip-ansi (. node.lines 2))]
      (faith.match "1 07/07/2026 Not" first)
      (faith.= nil (second:find "07/07/2026 Not" 1 true))
      (faith.= nil (second:find "1 07/07/2026 Not" 1 true)))))

(fn test-split-preview-shows-deleted-line-blame []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :change :old "gone" :old-no 3}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")
        state {:revision "HEAD"
               :split_cache {key rows}
               :preview_wrap? true
               :show_numbers? true
               :show_blame? true
               :split_ratio 0.5
               :preview_scroll 0
               :preview_x_scroll 0
               :full_context? false}
        old-blame-lines preview.blame-lines]
    (set preview.blame-lines
         (fn [_state _entry side]
           (if (= side :old) {3 "03/03/2020 Old"} {})))
    (view.prepare state 5 80 {:entry entry})
    (set preview.blame-lines old-blame-lines)
    (let [node (view.body state 5 80)
          text (tui.strip-ansi (. node.lines 1))]
      (faith.match "3 03/03/2020 Old" text))))

(fn test-split-preview-colors-comment-rows-differently []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :change
               :old "# old comment"
               :new "# new comment"
               :old-no 1
               :new-no 1
               :emphasize? true
               :old-comment? true
               :new-comment? true}
              {:kind :change
               :old "old code"
               :new "new code"
               :old-no 2
               :new-no 2}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")
        state {:revision "HEAD"
               :split_cache {key rows}
               :preview_wrap? true
               :show_numbers? false
               :split_ratio 0.5
               :preview_scroll 0
               :preview_x_scroll 0
               :full_context? false}]
    (view.prepare state 5 80 {:entry entry})
    (let [node (view.body state 5 80)]
      (faith.is (string.find (. node.lines 1) "\27[38;5;124m" 1 true)
                "deleted comment side should use the comment color")
      (faith.is (string.find (. node.lines 1) "\27[38;5;28m" 1 true)
                "added comment side should use the comment color")
      (faith.= nil (string.find (. node.lines 1) "\27[31m" 1 true)
               "comment row should not use the plain red")
      (faith.= nil (string.find (. node.lines 1) "\27[32m" 1 true)
               "comment row should not use the plain green")
      (faith.is (string.find (. node.lines 2) "\27[31m" 1 true)
                "code row should keep the plain red")
      (faith.is (string.find (. node.lines 2) "\27[32m" 1 true)
                "code row should keep the plain green"))))

(fn test-split-preview-colors-moved-rows-orange-with-a-note []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :change
               :old "gone elsewhere to a completely different place in the file"
               :old-no 3
               :old-move {:start 19 :stop 19 :first? true}}
              {:kind :change
               :new "arrived here"
               :new-no 19
               :new-move {:start 3 :stop 3 :first? true}}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")
        state {:revision "HEAD"
               :split_cache {key rows}
               :preview_wrap? true
               :show_numbers? false
               :split_ratio 0.5
               :preview_scroll 0
               :preview_x_scroll 0
               :full_context? false}]
    (view.prepare state 12 80 {:entry entry})
    (let [node (view.body state 12 80)
          first (. node.lines 1)
          collapsed (-> (tui.strip-ansi (table.concat node.lines "\n"))
                        (string.gsub "[^%w()]" ""))]
      (faith.is (string.find first "\27[38;5;208m" 1 true)
                "moved removed side should be orange")
      (faith.= nil (string.find first "\27[31m" 1 true))
      (faith.is (string.find (. node.lines 2) "\27[38;5;208m" 1 true)
                "wrapped continuation should stay orange")
      (faith.match "goneelsewhere.*%(movedtoline19%)" collapsed)
      (faith.match "arrivedhere%(movedfromline3%)" collapsed))))

(fn test-split-preview-marks-blank-line-changes-in-whitespace-hunks []
  (let [entry {:status "M" :kind "M" :path "a.rb"}
        rows [{:kind :change :old "" :old-no 5 :whitespace-hunk? true}
              {:kind :change :new "" :new-no 7 :whitespace-hunk? true}
              {:kind :change :old "" :old-no 9}]
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
    (let [node (view.body state 5 40)]
      (faith.is (string.find (. node.lines 1) "\27[41m" 1 true)
                "deleted blank line should carry the red background")
      (faith.is (string.find (. node.lines 2) "\27[42m" 1 true)
                "added blank line should carry the green background")
      (faith.= nil (string.find (. node.lines 3) "\27[41m" 1 true)
               "blank line outside a whitespace hunk should stay plain"))))

{: test-wrap-rows-keeps-short-rows-as-a-single-visual-row
 : test-split-preview-colors-comment-rows-differently
 : test-split-preview-marks-blank-line-changes-in-whitespace-hunks
 : test-split-preview-colors-moved-rows-orange-with-a-note
 : test-wrap-rows-splits-long-side-and-pads-shorter
 : test-wrap-rows-wraps-full-width-rows-across-content
 : test-split-preview-gutter-shows-blame-next-to-numbers
 : test-split-preview-leaves-wrapped-continuation-gutter-blank
 : test-split-preview-shows-deleted-line-blame
 : test-prepare-reuses-cached-split-layout}
