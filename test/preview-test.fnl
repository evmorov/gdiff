(local faith (require :faith))
(local git (require :git.core))
(local preview (require :preview.core))
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

(fn test-horizontal_scroll_limit_uses_visible_line_width []
  (let [state (state)]
    (set state.preview_x_scroll 20)
    (preview.set-horizontal-scroll-limit state
                                         ["short" "\27[32mabcdefghij\27[0m"] 6)
    (faith.= 4 state.preview_x_max_scroll)
    (faith.= 4 state.preview_x_scroll)
    (preview.set-horizontal-scroll-limit state ["short"] 6)
    (faith.= 0 state.preview_x_max_scroll)
    (faith.= 0 state.preview_x_scroll)))

(fn test-asset-preview-is-cheap-and-cached-without_git_diff []
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

(fn test-refresh-loaded-keeps-cache-and-caches-selected-preview []
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
    (update.update state {} {:type :refresh-loaded
                             :entries entries
                             :reviewed {}})
    (faith.= ["old preview"] (. state.preview_cache old-key))
    (faith.match "%+after" (t.text (. state.preview_cache key)))))

{: test-visible-lines-can-be-nonblocking-while-warming
 : test-asset-preview-is-cheap-and-cached-without_git_diff
 : test-horizontal_scroll_limit_uses_visible_line_width
 : test-refresh-loaded-keeps-cache-and-caches-selected-preview
 : test-scroll-info-only-appears-when-preview-overflows
 : test-startup-can-cache-selected-preview-before-rendering
 : test-visible-lines-renders-and-caches-real-git-preview}
