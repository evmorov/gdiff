(local action-plan (require :app.action_plan))
(local faith (require :faith))

(fn entry [path]
  {:path path :kind "M"})

(fn test-selected_target_prefers_tree_folder []
  (faith.= {:kind :folder :path "src"}
           (action-plan.selected-target :tree {:type :folder :path "src"}
                                        (entry "src/a.rb"))))

(fn test-selected_target_uses_entry_for_files_and_flat_mode []
  (let [selected (entry "src/a.rb")]
    (faith.= {:kind :file :path "src/a.rb" :entry selected}
             (action-plan.selected-target :tree {:type :file :entry selected}
                                          selected))
    (faith.= {:kind :file :path "src/a.rb" :entry selected}
             (action-plan.selected-target :flat nil selected))))

(fn test-copy_path_adds_slash_only_for_folders []
  (faith.= "src/" (action-plan.copy-path {:kind :folder :path "src"}))
  (faith.= "src/a.rb" (action-plan.copy-path {:kind :file :path "src/a.rb"}))
  (faith.= nil (action-plan.copy-path nil)))

(fn test-split_ratio_is_clamped []
  (faith.= 0.45 (action-plan.split-ratio 0.4 0.05))
  (faith.= 0.1 (action-plan.split-ratio 0.1 -0.05))
  (faith.= 0.9 (action-plan.split-ratio 0.9 0.05)))

{: test-copy_path_adds_slash_only_for_folders
 : test-selected_target_prefers_tree_folder
 : test-selected_target_uses_entry_for_files_and_flat_mode
 : test-split_ratio_is_clamped}
