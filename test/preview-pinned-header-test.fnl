(local faith (require :faith))
(local preview (require :preview.core))
(local format (require :preview.format))
(local preview-key (require :preview.key))
(local preview-view (require :app.view.preview))
(local split-view (require :app.view.preview-split))
(local symbols (require :tui.symbols))
(local theme (require :tui.theme))
(local tui (require :tui.core))

(local entry {:status "M" :kind "M" :path "lib/a.rb"})

(fn content-lines [count]
  (fcollect [i 1 count]
    (.. "line " i)))

(fn unified-state [scroll]
  (let [lines (format.header {:theme theme.default} entry.path entry)
        key (preview-key.for-entry "HEAD" entry false)]
    (each [_ line (ipairs (content-lines 10))]
      (table.insert lines line))
    {:revision "HEAD"
     :theme theme.default
     :preview_cache {key lines}
     :preview_wrap? false
     :split_ratio 0.5
     :preview_scroll scroll
     :preview_cursor 1
     :preview_x_scroll 0
     :full_context? false
     :focus :left}))

(fn split-state [scroll]
  (let [rows [{:kind :filename :old "a.rb" :new "a.rb"}
              {:kind :rule :old "a.rb" :new "a.rb"}]
        key (.. (preview-key.for-entry "HEAD" entry false) "\0split")]
    (for [i 1 10]
      (table.insert rows {:kind :context
                          :old (.. "line " i)
                          :new (.. "line " i)
                          :old-no i
                          :new-no i}))
    {:revision "HEAD"
     :theme theme.default
     :split_cache {key rows}
     :preview_wrap? false
     :split_ratio 0.5
     :preview_scroll scroll
     :preview_cursor 1
     :preview_x_scroll 0
     :full_context? false
     :focus :left}))

(fn body-text [node]
  (icollect [_ line (ipairs node.lines)]
    (tui.strip-ansi line)))

(fn rule? [text]
  (not= nil (text:find symbols.line.horizontal 1 true)))

(fn test-header-rows-finds-title-and-rule []
  (faith.= 2 (format.header-rows (format.header {:theme theme.default}
                                                "lib/a.rb" entry)))
  (faith.= 0 (format.header-rows ["a" "b"]))
  (faith.= 0 (format.header-rows ["Loading preview..."])))

(fn test-unified-header-stays-on-top-when-scrolled []
  (let [state (unified-state 4)]
    (preview-view.prepare state 5 40 {: entry})
    (let [text (body-text (preview-view.body state 5))]
      (faith.match "^lib/a%.rb" (. text 1))
      (faith.is (rule? (. text 2)))
      (faith.match "^line 5" (. text 3)))))

(fn test-unified-header-scrolls-normally-at-top []
  (let [state (unified-state 0)]
    (preview-view.prepare state 5 40 {: entry})
    (let [text (body-text (preview-view.body state 5))]
      (faith.match "^lib/a%.rb" (. text 1))
      (faith.match "^line 1" (. text 3)))))

(fn test-split-header-stays-on-top-when-scrolled []
  (let [state (split-state 4)]
    (split-view.prepare state 5 60 {: entry})
    (let [text (body-text (split-view.body state 5 60))]
      (faith.match "^a%.rb" (. text 1))
      (faith.is (rule? (. text 2)))
      (faith.match "^line 5" (. text 3)))))

(fn scrolled-state [scroll cursor]
  {:preview_pinned_rows 2
   :preview_rows 5
   :preview_total 20
   :preview_scroll scroll
   :preview_cursor cursor})

(fn test-cursor-moving-up-stays-below-pinned-header []
  (let [state (scrolled-state 5 8)]
    (preview.move-cursor state -1)
    (faith.= 7 state.preview_cursor)
    (faith.= 4 state.preview_scroll)))

(fn test-cursor-reaching-first-content-line-scrolls-to-top []
  (let [state (scrolled-state 1 4)]
    (preview.move-cursor state -1)
    (faith.= 3 state.preview_cursor)
    (faith.= 0 state.preview_scroll)))

(fn test-follow-scroll-keeps-cursor-below-pinned-header []
  (let [state (scrolled-state 5 6)]
    (preview.follow-scroll state)
    (faith.= 8 state.preview_cursor)))

(fn test-focus-cursor-starts-below-pinned-header []
  (let [state (scrolled-state 5 1)]
    (preview.focus-cursor state)
    (faith.= 8 state.preview_cursor)))

(fn test-header-is-not-pinned-when-few-rows-are-visible []
  (let [state {}]
    (preview.set-pinned-rows state 2 3)
    (faith.= 0 state.preview_pinned_rows)
    (preview.set-pinned-rows state 2 4)
    (faith.= 2 state.preview_pinned_rows)))

{: test-cursor-moving-up-stays-below-pinned-header
 : test-cursor-reaching-first-content-line-scrolls-to-top
 : test-focus-cursor-starts-below-pinned-header
 : test-follow-scroll-keeps-cursor-below-pinned-header
 : test-header-is-not-pinned-when-few-rows-are-visible
 : test-header-rows-finds-title-and-rule
 : test-split-header-stays-on-top-when-scrolled
 : test-unified-header-scrolls-normally-at-top
 : test-unified-header-stays-on-top-when-scrolled}
