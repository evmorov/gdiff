(local faith (require :faith))
(local plan (require :app.search-plan))

(fn test-start-and-clear-return-empty-search-shapes []
  (faith.= {:active? true :query "" :matches [] :index 0} (plan.start))
  (faith.= {:active? false :query "" :matches [] :index 0} (plan.clear)))

(fn test-finish-preserves-query-matches-and-index []
  (let [matches [{:entry 1}]]
    (faith.= {:active? false :query "api" : matches :index 1}
             (plan.finish {:active? true :query "api" : matches :index 1}))))

(fn test-query-edit-helpers []
  (faith.= "ap" (plan.backspace-query "api"))
  (faith.= "" (plan.backspace-query ""))
  (faith.= "api" (plan.append-query "ap" "i")))

(fn test-printable-accepts-single-visible-chars []
  (faith.= true (plan.printable? "a"))
  (faith.= false (plan.printable? :enter))
  (faith.= false (plan.printable? "\127")))

{: test-finish-preserves-query-matches-and-index
 : test-printable-accepts-single-visible-chars
 : test-query-edit-helpers
 : test-start-and-clear-return-empty-search-shapes}
