(local faith (require :faith))
(local git (require :git.core))
(local assets (require :preview.assets))
(local preview (require :preview.core))
(local preview-file (require :preview.file))
(local preview-format (require :preview.format))
(local preview-key (require :preview.key))
(local tui (require :tui.core))
(local t (require :test-helper))
(local update (require :app.update))

(fn setup-repo []
  (t.init-repo)
  (t.write-file "app.rb" "before\n")
  (t.commit-all "initial")
  (t.write-file "app.rb" "before\nafter\n"))

(fn state []
  {:preview_cache {}
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
    (faith.match "app%.rb" rendered)
    (faith.match "after" rendered)
    (faith.= nil (string.find rendered "diff %-%-git"))
    (faith.= nil (string.find rendered "+after" 1 true))
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

(local commented-diff (table.concat ["--- a/app.rb"
                                     "+++ b/app.rb"
                                     "@@ -1,3 +1,4 @@"
                                     " # note"
                                     "-old code"
                                     "+new code"
                                     "+# added comment"
                                     " tail"]
                                    "\n"))

(fn line-index [lines needle]
  (accumulate [found nil i l (ipairs lines) &until found]
    (when (string.find (tui.strip-ansi l) needle 1 true) i)))

(fn test-preview-format-hides-comment-lines-when-enabled []
  (let [state (doto (state) (tset :hide_comments? true))
        lines (preview-format.diff-lines state commented-diff)
        text (t.text lines)]
    (faith.= nil (string.find text "# note" 1 true))
    (faith.= nil (string.find text "# added comment" 1 true))
    (faith.match "old code" text)
    (faith.match "new code" text)
    (faith.match "tail" text)))

(fn test-preview-format-keeps-line-numbers-of-surviving-lines []
  (let [state (doto (state) (tset :hide_comments? true))
        (lines numbers) (preview-format.diff-lines state commented-diff)]
    (faith.= 2 (. numbers (line-index lines "old code")))
    (faith.= 2 (. numbers (line-index lines "new code")))
    (faith.= 4 (. numbers (line-index lines "tail")))))

(fn test-preview-format-keeps-comments-without-a-known-path []
  (let [state (doto (state) (tset :hide_comments? true))
        lines (preview-format.diff-lines state
                                         "@@ -1,1 +1,1 @@\n-# old\n+# new")]
    (faith.match "# old" (t.text lines))
    (faith.match "# new" (t.text lines))))

(fn test-preview-format-keeps-comments-by-default []
  (let [lines (preview-format.diff-lines (state) commented-diff)]
    (faith.match "# note" (t.text lines))
    (faith.match "# added comment" (t.text lines))))

(fn test-preview-format-dims-changed-comment-lines []
  (let [state (state)
        diff (table.concat ["--- a/app.rb"
                            "+++ b/app.rb"
                            "@@ -1,3 +1,3 @@"
                            " ctx"
                            "-# gone remark old"
                            "-old code"
                            "+new code"
                            "+# fresh note added"]
                           "\n")
        lines (preview-format.diff-lines state diff)
        line (fn [needle] (. lines (line-index lines needle)))]
    (faith.= (tui.color state.theme :comment-deleted "# gone remark old")
             (line "# gone remark old"))
    (faith.= (tui.color state.theme :comment-added "# fresh note added")
             (line "# fresh note added"))
    (faith.is (string.find (line "# gone remark old") "\27[38;5;124m" 1 true)
              "deleted comment should use the darker red")
    (faith.is (string.find (line "# fresh note added") "\27[38;5;28m" 1 true)
              "added comment should use the darker green")
    (faith.is (string.find (line "new code") "\27[32m" 1 true)
              "added code should keep the plain green style")))

(fn test-hide-comments-uses-separate-key-and-filtered-diff []
  (t.init-repo)
  (t.write-file "app.rb" "# note\nbefore\n")
  (t.commit-all "initial")
  (t.write-file "app.rb" "# note\nbefore\nafter\n")
  (let [(entries err) (git.diff-entries "HEAD")
        entry (. entries 1)
        state (state)
        normal (preview.lines state entry)
        normal-key (preview-key.for-entry "HEAD" entry)]
    (faith.= nil err)
    (set state.hide_comments? true)
    (let [hidden (preview.lines state entry)
          hidden-key (preview-key.for-entry "HEAD" entry nil true)]
      (faith.not= normal-key hidden-key)
      (faith.= normal (. state.preview_cache normal-key))
      (faith.= hidden (. state.preview_cache hidden-key))
      (faith.match "# note" (t.text normal))
      (faith.= nil (string.find (t.text hidden) "# note" 1 true)))))

(fn test-visible-lines-can-be-nonblocking-while-warming []
  (let [entry {:status "M" :kind "M" :path "missing.rb" :reviewed false}
        state {:preview_cache {}
               :preview_rows 1
               :preview_scroll 0
               :preview_warm {:dir "warm"}
               :revision "HEAD"}
        lines (preview.visible-lines state entry 20 {:nonblocking? true})]
    (faith.= "Loading preview..." (t.text lines))
    (faith.= 0 (t.count-pairs state.preview_cache))))

(fn test-warm-entry-bundles-unified-lines-and-split-rows []
  (setup-repo)
  (let [(entries err) (git.diff-entries "HEAD")
        entry (. entries 1)
        data (preview.warm-entry (state) entry)]
    (faith.= nil err)
    (faith.match "after" (t.text data.lines))
    (faith.is (< 0 (length data.split)) "an M file should warm split rows")))

(fn test-split-rows-is-nonblocking-while-warming []
  (let [entry {:status "M" :kind "M" :path "missing.rb" :reviewed false}
        state {:revision "HEAD" :split_cache {} :preview_warm {:dir "warm"}}
        old-plain-diff-output git.plain-diff-output]
    (set git.plain-diff-output
         (fn [...]
           (error "split-rows should not load git while warming")))
    (let [rows (preview.split-rows state entry)]
      (set git.plain-diff-output old-plain-diff-output)
      (faith.= [] rows))))

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
        old-plain-diff-output git.plain-diff-output]
    (set state.preview_rows 10)
    (set state.preview_total 100)
    (set git.plain-diff-output
         (fn [...]
           (error "scroll should not load preview lines")))
    (faith.= true (preview.scroll state entry 5))
    (set git.plain-diff-output old-plain-diff-output)
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
        lines (preview-format.diff-lines state
                                         "diff --git a/f b/f\nindex 1..2 100644\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n-context\n+added")
        text (t.text lines)]
    (faith.match "added" text)
    (faith.match "context" text)
    (faith.= nil (string.find text "diff %-%-git"))
    (faith.= nil (string.find text "+added" 1 true))
    (faith.= nil (string.find text "-context" 1 true))))

(fn line-with [lines needle]
  (accumulate [found nil _ l (ipairs lines) &until found]
    (when (string.find (tui.strip-ansi l) needle 1 true) l)))

(fn emphasized? [?line]
  (if (and ?line (or (string.find ?line "48;5;224" 1 true)
                     (string.find ?line "48;5;194" 1 true)))
      true
      false))

(fn emphasized-parts [?line]
  (if (not ?line)
      []
      (let [marked (-> ?line
                       (: :gsub "\27%[48;5;224m" "\0")
                       (: :gsub "\27%[48;5;194m" "\0")
                       (: :gsub "\27%[49m" "\1"))
            clean (tui.strip-ansi marked)
            out []]
        (each [part (clean:gmatch "%z([^\1]*)\1")]
          (table.insert out part))
        out)))

(fn test-preview-format-emphasizes-balanced-word-change []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1 +1 @@\n-foo bar baz\n+foo qux baz")]
    (faith.is (emphasized? (line-with lines "foo bar baz"))
              "removed word should be emphasized")
    (faith.is (emphasized? (line-with lines "foo qux baz"))
              "added word should be emphasized")))

(fn test-preview-format-emphasizes-the-similar-line-in-an-unbalanced-block []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,2 +1,3 @@\n-    class Configuration\n-      attr_reader :socket_path\n+    class Configuration < Base\n+      config_name :metrics\n+      # comment")]
    (faith.is (emphasized? (line-with lines "class Configuration < Base"))
              "the similar class line should be emphasized")
    (faith.= false (emphasized? (line-with lines "config_name :metrics")))
    (faith.= false (emphasized? (line-with lines "attr_reader :socket_path")))
    (faith.= false (emphasized? (line-with lines "# comment")))))

(fn test-preview-format-skips-emphasis-for-too-different-lines []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1 +1 @@\n-the quick brown fox\n+a slow green turtle swims")]
    (faith.= false (emphasized? (line-with lines "quick brown")))
    (faith.= false (emphasized? (line-with lines "slow green")))))

(fn test-preview-format-keeps-prefix-only-changes-plain []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,4 +1,5 @@\n around do\n   example.run\n-    Epoxy::Metrics.instance_variable_set(:@configuration, nil)\n+  ensure\n+    Epoxy::Metrics.reset_configuration!\n   end")]
    (faith.= false (emphasized? (line-with lines "instance_variable_set")))
    (faith.= false (emphasized? (line-with lines "reset_configuration")))
    (faith.= false (emphasized? (line-with lines "ensure")))))

(fn test-preview-format-pairs-by-similarity-not-position []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,3 +1 @@\n-totally different\n-another unrelated\n-keep aaa tail\n+keep bbb tail")]
    (faith.is (emphasized? (line-with lines "keep aaa tail")))
    (faith.is (emphasized? (line-with lines "keep bbb tail")))
    (faith.= false (emphasized? (line-with lines "totally different")))
    (faith.= false (emphasized? (line-with lines "another unrelated")))))

(fn test-preview-format-emphasizes-only-the-extra-leading-space []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,3 +1,3 @@\n def foo\n-      it \"x\" do\n+    it \"x\" do\n end")
        matches (icollect [_ l (ipairs lines)]
                  (when (string.find (tui.strip-ansi l) "it \"x\" do" 1 true) l))]
    (faith.= ["  "] (emphasized-parts (. matches 1)))
    (faith.= [] (emphasized-parts (. matches 2)))))

(fn test-preview-format-has-no-leading-gutter []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,2 +1,2 @@\n ctx line\n-old line\n+new line")]
    (faith.= "ctx line" (tui.strip-ansi (line-with lines "ctx line")))
    (faith.= "old line" (tui.strip-ansi (line-with lines "old line")))
    (faith.= "new line" (tui.strip-ansi (line-with lines "new line")))))

(fn test-preview-format-keeps-shared-words-as-anchors []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1 +1 @@\n-aaa bbb ccc ddd\n+aaa xxx ccc yyy")]
    (faith.= ["bbb" "ddd"]
             (emphasized-parts (line-with lines "aaa bbb ccc ddd")))
    (faith.= ["xxx" "yyy"]
             (emphasized-parts (line-with lines "aaa xxx ccc yyy")))))

(fn blank-change-line [lines]
  (accumulate [found nil _ l (ipairs lines) &until found]
    (when (= " " (tui.strip-ansi l)) l)))

(fn whitespace-marked? [?line]
  (and ?line
       (or (and (string.find ?line "\27[41m" 1 true) :deleted)
           (and (string.find ?line "\27[42m" 1 true) :added))))

(fn test-preview-format-marks-removed-blank-line []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,3 +1,2 @@\n ctx\n-\n keep")
        blank (blank-change-line lines)]
    (faith.is blank "expected the removed blank line to stay visible")
    (faith.= :deleted (whitespace-marked? blank))))

(fn test-preview-format-marks-added-blank-line []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,2 +1,3 @@\n ctx\n+\n keep")
        blank (blank-change-line lines)]
    (faith.is blank "expected the added blank line to stay visible")
    (faith.= :added (whitespace-marked? blank))))

(fn test-preview-format-marks-whitespace-only-change []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,2 +1,2 @@\n ctx\n-  \n+ ")]
    (faith.= :deleted (whitespace-marked? (line-with lines "  ")))))

(fn test-preview-format-keeps-blank-lines-plain-next-to-real-changes []
  (let [lines (preview-format.diff-lines (state)
                                         "@@ -1,4 +1,3 @@\n ctx\n-old\n+new\n keep\n-")]
    (faith.= nil (blank-change-line lines)
             "blank line in a hunk with real changes should stay plain")))

(fn test-preview-format-marks-whitespace-hunks-independently []
  (let [lines (preview-format.diff-lines (state)
                                         (.. "@@ -1,2 +1,1 @@\n ctx\n-\n"
                                             "@@ -10,3 +9,2 @@\n keep\n-a\n+b\n-"))
        marked (icollect [_ l (ipairs lines)]
                 (when (= " " (tui.strip-ansi l)) l))]
    (faith.= 1 (length marked)
             "only the whitespace-only hunk's blank line should be visible")
    (faith.= :deleted (whitespace-marked? (. marked 1)))))

(fn test-asset-preview-is-cheap-and-cached-without-git-diff []
  (let [entry {:status "M" :kind "M" :path "icons/logo.svg" :reviewed false}
        state (state)
        old-plain-diff-output git.plain-diff-output]
    (set git.plain-diff-output
         (fn [...]
           (error "asset preview should not call git diff")))
    (let [lines (preview.lines state entry)]
      (set git.plain-diff-output old-plain-diff-output)
      (faith.= "Asset preview skipped: icons/logo.svg" (t.text lines))
      (faith.= lines
               (. state.preview_cache (preview-key.for-entry "HEAD" entry))))))

(fn untracked-entry [entries]
  (accumulate [found nil _ entry (ipairs entries) &until found]
    (when entry.untracked? entry)))

(fn test-untracked-file-preview-shows-added-content-and-caches []
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
    (faith.= (tui.color state.theme :status-added "alpha")
             (line-with lines "alpha"))
    (faith.= (tui.color state.theme :status-added "beta")
             (line-with lines "beta"))
    (faith.= lines (. state.preview_cache key))))

(fn test-untracked-file-preview-shows-line-numbers []
  (t.init-repo)
  (t.write-file "app.rb" "before\n")
  (t.commit-all "initial")
  (t.write-file "__init__.py" "import os\n\nVALUE = 1\n")
  (let [(entries err) (git.diff-entries git.working-revision)
        entry (untracked-entry entries)
        state (doto (state)
                (tset :revision git.working-revision)
                (tset :show_numbers? true))
        (lines gutters) (preview.selection-lines state entry nil)]
    (faith.= nil err)
    (faith.= true entry.untracked?)
    (faith.= (length lines) (length gutters))
    (faith.= false (. gutters 1))
    (faith.= false (. gutters 2))
    (faith.= "1" (tui.strip-ansi (. gutters 3)))
    (faith.= "2" (tui.strip-ansi (. gutters 4)))
    (faith.= "3" (tui.strip-ansi (. gutters 5)))))

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
    (faith.match "after" (t.text (. state.preview_cache key)))))

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
    (faith.match "after" (t.text (. state.preview_cache key)))))

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
    (let [first (preview.display-lines-for-width state lines nil 2 10)
          second (preview.display-lines-for-width state lines nil 2 10)]
      (faith.= first second)
      (faith.= first state.preview_display_cache.display))))

(fn test-display-lines-for-width-invalidates-when-layout-changes []
  (let [state (state)
        lines ["abcdefghijklmnopqrstuvwxyz"]]
    (set state.preview_wrap? true)
    (set state.split_ratio 0.5)
    (let [first (preview.display-lines-for-width state lines nil 2 10)
          second (preview.display-lines-for-width state lines nil 2 20)]
      (faith.not= first second)
      (faith.= 20 state.preview_display_cache.cols))))

(fn test-visible-count-never-drops-below-one []
  (faith.= 1 (preview.visible-count nil))
  (faith.= 1 (preview.visible-count 0))
  (faith.= 3 (preview.visible-count 3)))

(fn gutter-contains? [gutters needle]
  (accumulate [found false _ gutter (ipairs (or gutters [])) &until found]
    (or found (not (= nil (string.find (tui.strip-ansi gutter) needle 1 true))))))

(fn test-unified-preview-gutter-combines-line-number-and-blame []
  (let [entry {:status "M" :kind "M" :path "app.rb" :reviewed false}
        state (state)
        old-plain-diff-output git.plain-diff-output
        old-blame-lines git.blame-lines]
    (set state.show_numbers? true)
    (set state.show_blame? true)
    (set state.preview_wrap? true)
    (set state.split_ratio 0.5)
    (set git.plain-diff-output (fn [_revision _entry _full?]
                                 (values "@@ -1,2 +1,2 @@\n before\n-old\n+new"
                                         true)))
    (set git.blame-lines
         (fn [_revision _entry side]
           (if (= side :old)
               {2 "29/04/2021 Evgenii"}
               {1 "28/04/2021 Ada" 2 "30/04/2021 Grace"})))
    (let [(lines gutters) (preview.selection-lines state entry nil)]
      (preview.display-lines-for-width state lines gutters 20 100)
      (set git.plain-diff-output old-plain-diff-output)
      (set git.blame-lines old-blame-lines)
      (let [visible (preview.display-gutters state)]
        (faith.is (gutter-contains? visible "1 28/04/2021 Ada"))
        (faith.is (gutter-contains? visible "2 29/04/2021 Evgenii"))))))

(fn test-unified-blame-gutter-is-left-aligned []
  (let [state (state)
        entry {:path "app.rb"}
        old-blame-lines git.blame-lines]
    (set state.show_blame? true)
    (set git.blame-lines
         (fn [_revision _entry _side]
           {1 "26/06/2026 Evgenii" 2 "07/07/2026 Not"}))
    (let [gutters (preview.line-gutters state entry nil
                                        [{:side :new :no 1} {:side :new :no 2}])]
      (set git.blame-lines old-blame-lines)
      (faith.= "26/06/2026 Evgenii" (. (. gutters 1) :full))
      (faith.match "^07/07/2026 Not" (. (. gutters 2) :full)))))

(fn test-unified-blame-gutter-is-blank-on-wrapped-continuation-lines []
  (let [state (state)
        entry {:path "app.rb"}
        old-blame-lines git.blame-lines]
    (set state.show_blame? true)
    (set state.preview_wrap? true)
    (set state.split_ratio 0.5)
    (set git.blame-lines (fn [_revision _entry _side]
                           {1 "07/07/2026 Not"}))
    (let [gutters (preview.line-gutters state entry nil [{:side :new :no 1}])
          lines ["abcdefghijklmnopqrstuvwxyz"]]
      (preview.display-lines-for-width state lines gutters 20 44)
      (set git.blame-lines old-blame-lines)
      (let [visible (preview.display-gutters state)]
        (faith.is (< 1 (length visible)))
        (faith.match "^07/07/2026 Not" (tui.strip-ansi (. visible 1)))
        (faith.match "^%s*$" (tui.strip-ansi (. visible 2)))))))

(fn test-unified-blame-gutter-shows-deleted-line-blame []
  (let [state (state)
        entry {:path "app.rb"}
        old-blame-lines git.blame-lines]
    (set state.show_blame? true)
    (set git.blame-lines
         (fn [_revision _entry side]
           (if (= side :old) {3 "03/03/2020 Old"} {})))
    (let [gutters (preview.line-gutters state entry nil [{:side :old :no 3}])]
      (set git.blame-lines old-blame-lines)
      (faith.= "03/03/2020 Old" (. (. gutters 1) :full)))))

(fn test-unified-blame-requests-only-diff-line-ranges []
  (let [state (state)
        entry {:path "app.rb"}
        old-blame-lines git.blame-lines
        captured {}]
    (set state.show_blame? true)
    (set git.blame-lines (fn [_revision _entry side ranges]
                           (tset captured side ranges)
                           {}))
    (preview.line-gutters state entry nil
                          [{:side :new :no 1}
                           {:side :old :no 2}
                           {:side :new :no 2}])
    (set git.blame-lines old-blame-lines)
    (faith.= [[2 2]] (. captured :old))
    (faith.= [[1 2]] (. captured :new))))

{: test-full-context-uses-separate-key-and-wider-diff
 : test-hide-comments-uses-separate-key-and-filtered-diff
 : test-preview-format-hides-comment-lines-when-enabled
 : test-preview-format-keeps-line-numbers-of-surviving-lines
 : test-preview-format-keeps-comments-without-a-known-path
 : test-preview-format-keeps-comments-by-default
 : test-preview-format-dims-changed-comment-lines
 : test-visible-lines-can-be-nonblocking-while-warming
 : test-warm-entry-bundles-unified-lines-and-split-rows
 : test-split-rows-is-nonblocking-while-warming
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
 : test-preview-format-emphasizes-balanced-word-change
 : test-preview-format-emphasizes-the-similar-line-in-an-unbalanced-block
 : test-preview-format-skips-emphasis-for-too-different-lines
 : test-preview-format-keeps-prefix-only-changes-plain
 : test-preview-format-pairs-by-similarity-not-position
 : test-preview-format-emphasizes-only-the-extra-leading-space
 : test-preview-format-has-no-leading-gutter
 : test-preview-format-keeps-shared-words-as-anchors
 : test-preview-format-marks-removed-blank-line
 : test-preview-format-marks-added-blank-line
 : test-preview-format-marks-whitespace-only-change
 : test-preview-format-keeps-blank-lines-plain-next-to-real-changes
 : test-preview-format-marks-whitespace-hunks-independently
 : test-refresh-loaded-clears-folder-preview-cache
 : test-refresh-loaded-clears-stale-cache-and-caches-selected-preview
 : test-selection-lines-renders-folder-rows-through-preview-core
 : test-scroll-uses-rendered-preview-total-without-loading-diff
 : test-scroll-info-only-appears-when-preview-overflows
 : test-startup-can-cache-selected-preview-before-rendering
 : test-untracked-file-preview-shows-added-content-and-caches
 : test-untracked-file-preview-shows-line-numbers
 : test-selection-lines-previews-expanded-listing-file
 : test-selection-lines-skips-binary-listing-file
 : test-preview-file-detects-binary-content
 : test-preview-file-split-keeps-empty-lines-and-drops-trailing-newline
 : test-visible-count-never-drops-below-one
 : test-unified-preview-gutter-combines-line-number-and-blame
 : test-unified-blame-gutter-is-left-aligned
 : test-unified-blame-gutter-is-blank-on-wrapped-continuation-lines
 : test-unified-blame-gutter-shows-deleted-line-blame
 : test-unified-blame-requests-only-diff-line-ranges
 : test-visible-lines-renders-and-caches-real-git-preview}
