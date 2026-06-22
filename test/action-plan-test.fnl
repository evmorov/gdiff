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

(fn test-copy-path-adds-slash-only-for-folders []
  (faith.= "src/" (action-plan.copy-path {:kind :folder :path "src"}))
  (faith.= "src/a.rb" (action-plan.copy-path {:kind :file :path "src/a.rb"}))
  (faith.= nil (action-plan.copy-path nil)))

(fn test-split-ratio-is-clamped []
  (faith.= 0.45 (action-plan.split-ratio 0.4 0.05))
  (faith.= 0.1 (action-plan.split-ratio 0.1 -0.05))
  (faith.= 0.9 (action-plan.split-ratio 0.9 0.05)))

{: test-copy-path-adds-slash-only-for-folders
 : test-selected-target-prefers-tree-folder
 : test-selected-target-uses-entry-for-files-and-flat-mode
 : test-selected-target-uses-path-for-unchanged-tree-files
 : test-split-ratio-is-clamped}
