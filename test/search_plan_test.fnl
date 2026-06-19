(local faith (require :faith))
(local plan (require :app.search_plan))

(fn test-start_and_clear_return_empty_search_shapes []
  (faith.= {:active? true :query "" :matches [] :index 0} (plan.start))
  (faith.= {:active? false :query "" :matches [] :index 0} (plan.clear)))

(fn test-finish_preserves_query_matches_and_index []
  (let [matches [{:entry 1}]]
    (faith.= {:active? false :query "api" : matches :index 1}
             (plan.finish {:active? true :query "api" : matches :index 1}))))

(fn test-query_edit_helpers []
  (faith.= "ap" (plan.backspace-query "api"))
  (faith.= "" (plan.backspace-query ""))
  (faith.= "api" (plan.append-query "ap" "i")))

(fn test-printable_accepts_single_visible_chars []
  (faith.= true (plan.printable? "a"))
  (faith.= false (plan.printable? :enter))
  (faith.= false (plan.printable? "\127")))

{: test-finish_preserves_query_matches_and_index
 : test-printable_accepts_single_visible_chars
 : test-query_edit_helpers
 : test-start_and_clear_return_empty_search_shapes}
