(local faith (require :faith))
(local git (require :git.core))
(local assets (require :preview.assets))
(local preview (require :preview.core))
(local preview-file (require :preview.file))
(local preview-format (require :preview.format))
(local preview-key (require :preview.key))
(local t (require :test-helper))
(local update (require :app.update))

(fn setup-repo []
  (t.init-repo)
  (t.write-file "app.rb" "before\n")
  (t.commit-all "initial")
  (t.write-file "app.rb" "before\nafter\n"))

(fn state []
  {:preview_cache {}
   :preview_context (git.preview-context)
   :preview_rows 1
   :preview_scroll 0
   :preview_total 0
   :revision "HEAD"})

(fn test-visible-lines-renders-and-caches-real-git-preview []
  (setup-repo)
  (let [(entries err) (git.diff-entries "HEAD")
        state (state)
        lines (preview.visible-lines state (. entries 1) 20)
        rendered (t.text lines)]
    (faith.= nil err)
    (faith.match "diff %-%-git" rendered)
    (faith.match "%+after" rendered)
    (faith.= 1 (t.count-pairs state.preview_cache))
    (t.write-file "app.rb" "changed after cache\n")
    (faith.= lines (preview.visible-lines state (. entries 1) 20))))

(fn test-full-context-uses-separate-key-and-wider-diff []
  (t.init-repo)
  (let [padding (string.rep "line\n" 30)]
    (t.write-file "big.rb" (.. padding "old\n" padding))
    (t.commit-all "initial")
    (t.write-file "big.rb" (.. padding "new\n" padding)))
  (let [(entries err) (git.diff-entries "HEAD")
        entry (. entries 1)
        state (state)
        normal (preview.lines state entry)
        normal-key (preview-key.for-entry "HEAD" entry)]
    (faith.= nil err)
    (set state.full_context? true)
    (let [full (preview.lines state entry)
          full-key (preview-key.for-entry "HEAD" entry true)]
      (faith.not= normal-key full-key)
      (faith.= normal (. state.preview_cache normal-key))
      (faith.= full (. state.preview_cache full-key))
      (faith.is (> (length full) (length normal))
                "full context should render more lines than the default diff"))))

(fn test-visible-lines-can-be-nonblocking-while-warming []
  (let [entry {:status "M" :kind "M" :path "missing.rb" :reviewed false}
        state {:preview_cache {}
               :preview_context {}
               :preview_rows 1
               :preview_scroll 0
               :preview_warm {:dir "warm"}
               :revision "HEAD"}
        lines (preview.visible-lines state entry 20 {:nonblocking? true})]
    (faith.= "Loading preview..." (t.text lines))
    (faith.= 0 (t.count-pairs state.preview_cache))))

(fn test-scroll-info-only-appears-when-preview-overflows []
  (let [entry {:status "M" :kind "M" :path "a.rb" :reviewed false}
        state (state)
        key (preview-key.for-entry "HEAD" entry)]
    (tset state.preview_cache key ["1" "2" "3" "4" "5"])
    (faith.= ["1" "2" "3"] (preview.visible-lines state entry 3))
    (faith.= {:offset 0 :total 5 :visible 3} (preview.scroll-info state))
    (faith.= ["1" "2" "3" "4" "5"] (preview.visible-lines state entry 5))
    (faith.= nil (preview.scroll-info state))))

(fn test-scroll-uses-rendered-preview-total-without-loading-diff []
  (let [entry {:status "M" :kind "M" :path "missing.rb" :reviewed false}
        state (state)
        old-preview-output git.preview-output]
    (set state.preview_rows 10)
    (set state.preview_total 100)
    (set git.preview-output
         (fn [...]
           (error "scroll should not load preview lines")))
    (faith.= true (preview.scroll state entry 5))
    (set git.preview-output old-preview-output)
    (faith.= 5 state.preview_scroll)))

(fn test-horizontal-scroll-limit-uses-visible-line-width []
  (let [state (state)]
    (set state.preview_x_scroll 20)
    (preview.set-horizontal-scroll-limit state
                                         ["short" "\27[32mabcdefghij\27[0m"] 6)
    (faith.= 4 state.preview_x_max_scroll)
    (faith.= 4 state.preview_x_scroll)
    (preview.set-horizontal-scroll-limit state ["short"] 6)
    (faith.= 0 state.preview_x_max_scroll)
    (faith.= 0 state.preview_x_scroll)))

(fn test-horizontal-width-cache-follows-current-lines-table []
  (let [state (state)
        first ["abcdef"]
        second ["abcdefghijkl"]]
    (faith.= 6 (preview.cached-max-line-width state first))
    (faith.= 6 (preview.cached-max-line-width state first))
    (faith.= 12 (preview.cached-max-line-width state second))
    (faith.= second state.preview_width_lines)))

(fn test-apply-horizontal-scroll-limit-uses-split-width []
  (let [state (state)]
    (set state.split_ratio 0.5)
    (set state.preview_wrap? false)
    (set state.preview_x_scroll 99)
    (preview.apply-horizontal-scroll-limit state ["abcdefghij"] 20 false)
    (faith.= 0 state.preview_x_max_scroll)
    (faith.= 0 state.preview_x_scroll)
    (preview.apply-horizontal-scroll-limit state ["abcdefghijklmnopqrstuvwxyz"]
                                           20 true)
    (faith.= 17 state.preview_x_max_scroll)))

(fn test-apply-horizontal-scroll-limit-resets-when-wrapping []
  (let [state (state)]
    (set state.preview_wrap? true)
    (set state.preview_x_scroll 10)
    (preview.apply-horizontal-scroll-limit state ["abcdefghijklmnopqrstuvwxyz"]
                                           20 false)
    (faith.= 0 state.preview_x_max_scroll)
    (faith.= 0 state.preview_x_scroll)))

(fn test-asset-detection-covers-image-and-icon-extensions []
  (faith.= true (assets.asset? {:path "icons/logo.SVG"}))
  (faith.= true (assets.asset? {:path "favicon.ico"}))
  (faith.= true (assets.asset? {:path "screenshots/page.png"}))
  (faith.= false (assets.asset? {:path "src/app.fnl"})))

(fn test-preview-format-colors-diff-lines []
  (let [state (state)
        lines (preview-format.output-lines state
                                           "diff --git a b\n+added\n-context"
                                           false)
        text (t.text lines)]
    (faith.match "diff %-%-git a b" text)
    (faith.match "%+added" text)
    (faith.match "%-context" text)))

(fn test-asset-preview-is-cheap-and-cached-without-git-diff []
  (let [entry {:status "M" :kind "M" :path "icons/logo.svg" :reviewed false}
        state (state)
        old-preview-output git.preview-output]
    (set git.preview-output
         (fn [...]
           (error "asset preview should not call git diff")))
    (let [lines (preview.lines state entry)]
      (set git.preview-output old-preview-output)
      (faith.= "Asset preview skipped: icons/logo.svg" (t.text lines))
      (faith.= lines
               (. state.preview_cache (preview-key.for-entry "HEAD" entry))))))

(fn untracked-entry [entries]
  (accumulate [found nil _ entry (ipairs entries) &until found]
    (when entry.untracked? entry)))

(fn test-untracked-file-preview-shows-plain-content-and-caches []
  (t.init-repo)
  (t.write-file "app.rb" "before\n")
  (t.commit-all "initial")
  (t.write-file "notes.txt" "alpha\n\nbeta\n")
  (let [(entries err) (git.diff-entries git.working-revision)
        entry (untracked-entry entries)
        state (doto (state)
                (tset :revision git.working-revision))
        key (preview-key.for-entry git.working-revision entry)
        lines (preview.lines state entry)
        text (t.text lines)]
    (faith.= nil err)
    (faith.= "A" entry.status)
    (faith.= true entry.untracked?)
    (faith.= "notes.txt" (. lines 1))
    (faith.match "alpha" text)
    (faith.match "beta" text)
    (faith.= lines (. state.preview_cache key))))

(fn test-selection-lines-previews-expanded-listing-file []
  (t.init-repo)
  (t.write-file "util.rb" "puts :hi\n")
  (let [state {:view_mode :tree}
        row {:type :file :unchanged true :path "util.rb"}
        lines (preview.selection-lines state nil row)
        text (t.text lines)]
    (faith.= "util.rb" (. lines 1))
    (faith.match "puts :hi" text)))

(fn test-selection-lines-skips-binary-listing-file []
  (t.init-repo)
  (t.write-file "data.bin" "abc\0\1\2def")
  (let [state {:view_mode :tree}
        row {:type :file :unchanged true :path "data.bin"}
        lines (preview.selection-lines state nil row)]
    (faith.= "Binary file preview skipped: data.bin" (t.text lines))))

(fn test-preview-file-detects-binary-content []
  (faith.= true (preview-file.binary? "abc\0def"))
  (faith.= false (preview-file.binary? "plain text\n"))
  (faith.= false (preview-file.binary? "")))

(fn test-preview-file-split-keeps-empty-lines-and-drops-trailing-newline []
  (faith.= ["a" "" "b"] (preview-file.split-lines "a\n\nb\n"))
  (faith.= ["a" "b"] (preview-file.split-lines "a\r\nb\r\n"))
  (faith.= [] (preview-file.split-lines "")))

(fn test-startup-can-cache-selected-preview-before-rendering []
  (setup-repo)
  (let [(entries err) (git.diff-entries "HEAD")
        state (update.init "HEAD" entries {:version 1 :reviews {}} "scope"
                           "src")
        key (preview-key.for-entry "HEAD" (. entries 1))]
    (faith.= nil err)
    (faith.= 0 (t.count-pairs state.preview_cache))
    (update.cache-selected-preview state)
    (faith.= 1 (t.count-pairs state.preview_cache))
    (faith.match "%+after" (t.text (. state.preview_cache key)))))

(fn test-refresh-loaded-clears-stale-cache-and-caches-selected-preview []
  (setup-repo)
  (let [(entries err) (git.diff-entries "HEAD")
        state (update.init "HEAD" entries {:version 1 :reviews {}} "scope"
                           "src")
        old-key (preview-key.for-entry "HEAD"
                                       {:status "M"
                                        :kind "M"
                                        :path "old.rb"
                                        :reviewed false})
        key (preview-key.for-entry "HEAD" (. entries 1))]
    (faith.= nil err)
    (tset state.preview_cache old-key ["old preview"])
    (faith.= 1 (t.count-pairs state.preview_cache))
    (update.update state {} {:type :refresh-loaded : entries :reviewed {}})
    (faith.= nil (. state.preview_cache old-key))
    (faith.match "%+after" (t.text (. state.preview_cache key)))))

(fn test-refresh-loaded-clears-folder-preview-cache []
  (setup-repo)
  (let [(entries err) (git.diff-entries "HEAD")
        state (update.init "HEAD" entries {:version 1 :reviews {}} "scope"
                           "src")]
    (faith.= nil err)
    (set state.folder_preview_cache.src {:ok? true :output "cached"})
    (faith.= 1 (t.count-pairs state.folder_preview_cache))
    (update.update state {} {:type :refresh-loaded : entries :reviewed {}})
    (faith.= 0 (t.count-pairs state.folder_preview_cache))))

(fn test-selection-lines-renders-folder-rows-through-preview-core []
  (let [state {:view_mode :tree
               :entries [{:status "M"
                          :kind "M"
                          :path "src/a.rb"
                          :reviewed false}]
               :folder_preview_cache {"src" {:ok? true
                                             :output "total 0\n-rw-r--r--  1 u  g  1 Jan  1 00:00 a.rb\n"}}}
        row {:type :folder :path "src"}]
    (faith.= "[M] src/\n────────\n[M] a.rb"
             (t.text (preview.selection-lines state nil row)))))

(fn test-apply-display-lines-updates-preview-scroll-metadata []
  (let [state {:preview_scroll 10}]
    (faith.= {:offset 1 :total 3 :visible 2}
             (preview.apply-display-lines state ["a" "b" "c"] 2))
    (faith.= 2 state.preview_rows)
    (faith.= 3 state.preview_total)
    (faith.= 1 state.preview_scroll)
    (faith.= ["b" "c"] (preview.visible-display-lines state ["a" "b" "c"] 2))))

(fn test-display-lines-for-width-caches-stable-layout []
  (let [state (state)
        lines ["abcdefghijklmnopqrstuvwxyz"]]
    (set state.preview_wrap? true)
    (set state.split_ratio 0.5)
    (let [first (preview.display-lines-for-width state lines 2 10)
          second (preview.display-lines-for-width state lines 2 10)]
      (faith.= first second)
      (faith.= first state.preview_display_cache.display))))

(fn test-display-lines-for-width-invalidates-when-layout-changes []
  (let [state (state)
        lines ["abcdefghijklmnopqrstuvwxyz"]]
    (set state.preview_wrap? true)
    (set state.split_ratio 0.5)
    (let [first (preview.display-lines-for-width state lines 2 10)
          second (preview.display-lines-for-width state lines 2 20)]
      (faith.not= first second)
      (faith.= 20 state.preview_display_cache.cols))))

(fn test-visible-count-never-drops-below-one []
  (faith.= 1 (preview.visible-count nil))
  (faith.= 1 (preview.visible-count 0))
  (faith.= 3 (preview.visible-count 3)))

{: test-full-context-uses-separate-key-and-wider-diff
 : test-visible-lines-can-be-nonblocking-while-warming
 : test-apply-display-lines-updates-preview-scroll-metadata
 : test-apply-horizontal-scroll-limit-resets-when-wrapping
 : test-apply-horizontal-scroll-limit-uses-split-width
 : test-asset-detection-covers-image-and-icon-extensions
 : test-asset-preview-is-cheap-and-cached-without-git-diff
 : test-display-lines-for-width-caches-stable-layout
 : test-display-lines-for-width-invalidates-when-layout-changes
 : test-horizontal-width-cache-follows-current-lines-table
 : test-horizontal-scroll-limit-uses-visible-line-width
 : test-preview-format-colors-diff-lines
 : test-refresh-loaded-clears-folder-preview-cache
 : test-refresh-loaded-clears-stale-cache-and-caches-selected-preview
 : test-selection-lines-renders-folder-rows-through-preview-core
 : test-scroll-uses-rendered-preview-total-without-loading-diff
 : test-scroll-info-only-appears-when-preview-overflows
 : test-startup-can-cache-selected-preview-before-rendering
 : test-untracked-file-preview-shows-plain-content-and-caches
 : test-selection-lines-previews-expanded-listing-file
 : test-selection-lines-skips-binary-listing-file
 : test-preview-file-detects-binary-content
 : test-preview-file-split-keeps-empty-lines-and-drops-trailing-newline
 : test-visible-count-never-drops-below-one
 : test-visible-lines-renders-and-caches-real-git-preview}
