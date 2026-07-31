(local action-plan (require :app.action-plan))
(local faith (require :faith))

(fn entry [path]
  {: path :kind "M"})

(fn test-selected-target-prefers-tree-folder []
  (faith.= {:kind :folder :path "src"}
           (action-plan.selected-target :tree {:type :folder :path "src"}
                                        (entry "src/a.rb"))))

(fn test-selected-target-uses-entry-for-files-and-flat-mode []
  (let [selected (entry "src/a.rb")]
    (faith.= {:kind :file :path "src/a.rb" :entry selected}
             (action-plan.selected-target :tree {:type :file :entry selected}
                                          selected))
    (faith.= {:kind :file :path "src/a.rb" :entry selected}
             (action-plan.selected-target :flat nil selected))))

(fn test-selected-target-uses-path-for-unchanged-tree-files []
  (faith.= {:kind :file :path "src/.keep"}
           (action-plan.selected-target :tree
                                        {:type :file
                                         :unchanged true
                                         :path "src/.keep"}
                                        nil)))

(fn test-base-source-path-uses-old-path-for-renames []
  (faith.= "src/old.rb"
           (action-plan.base-source-path {:kind :file
                                          :path "src/new.rb"
                                          :entry {:path "src/new.rb"
                                                  :old_path "src/old.rb"}}))
  (faith.= "src/a.rb"
           (action-plan.base-source-path {:kind :file
                                          :path "src/a.rb"
                                          :entry {:path "src/a.rb"}}))
  (faith.= "src/.keep"
           (action-plan.base-source-path {:kind :file :path "src/.keep"}))
  (faith.= nil (action-plan.base-source-path nil)))

(fn test-open-plan-opens-working-tree-file-in-editor []
  (let [selected (entry "src/a.rb")]
    (faith.= {:action :editor :entry selected}
             (action-plan.open-plan {:kind :file
                                     :path "src/a.rb"
                                     :entry selected}
                                    nil))
    (faith.= {:action :editor :entry {:path "src/.keep"}}
             (action-plan.open-plan {:kind :file :path "src/.keep"} nil))
    (faith.= nil (action-plan.open-plan nil nil))))

(fn test-open-plan-uses-head-snapshot-for-pr-files []
  (let [pr-url "https://github.com/acme/widgets/pull/1"]
    (faith.= {:action :head-snapshot :path "src/a.rb"}
             (action-plan.open-plan {:kind :file
                                     :path "src/a.rb"
                                     :entry (entry "src/a.rb")}
                                    pr-url))
    (faith.= {:action :folder :path "src"}
             (action-plan.open-plan {:kind :folder :path "src"} pr-url))))

(fn test-copy-path-adds-slash-only-for-folders []
  (faith.= "src/" (action-plan.copy-path {:kind :folder :path "src"}))
  (faith.= "src/a.rb" (action-plan.copy-path {:kind :file :path "src/a.rb"}))
  (faith.= nil (action-plan.copy-path nil)))

(fn test-copy-full-path-prefixes-the-repo-root []
  (faith.= "/repo/src/a.rb"
           (action-plan.copy-full-path {:kind :file :path "src/a.rb"} "/repo"))
  (faith.= "/repo/src/"
           (action-plan.copy-full-path {:kind :folder :path "src"} "/repo"))
  (faith.= "src/a.rb" (action-plan.copy-full-path {:kind :file
                                                   :path "src/a.rb"}
                                                  nil))
  (faith.= nil (action-plan.copy-full-path nil "/repo")))

(fn test-fenced-snippet-prefixes-the-path-and-fences-the-text []
  (faith.= "a/b.rb\n\n```\nline1\nline2\n```"
           (action-plan.fenced-snippet "a/b.rb" "line1\nline2"))
  (faith.= "```\nline1\n```" (action-plan.fenced-snippet nil "line1")))

(fn test-split-ratio-is-clamped []
  (faith.= 0.45 (action-plan.split-ratio 0.4 0.05))
  (faith.= 0.1 (action-plan.split-ratio 0.1 -0.05))
  (faith.= 0.9 (action-plan.split-ratio 0.9 0.05)))

{: test-base-source-path-uses-old-path-for-renames
 : test-copy-full-path-prefixes-the-repo-root
 : test-fenced-snippet-prefixes-the-path-and-fences-the-text
 : test-copy-path-adds-slash-only-for-folders
 : test-open-plan-opens-working-tree-file-in-editor
 : test-open-plan-uses-head-snapshot-for-pr-files
 : test-selected-target-prefers-tree-folder
 : test-selected-target-uses-entry-for-files-and-flat-mode
 : test-selected-target-uses-path-for-unchanged-tree-files
 : test-split-ratio-is-clamped}
