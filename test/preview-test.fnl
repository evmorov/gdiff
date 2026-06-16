(local faith (require :faith))
(local git (require :git))
(local preview (require :preview))
(local t (require :test-helper))

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

{: test-visible-lines-renders-and-caches-real-git-preview}
