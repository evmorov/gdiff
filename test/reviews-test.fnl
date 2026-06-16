(local faith (require :faith))
(local reviews (require :reviews))
(local t (require :test-helper))

(fn entry [path reviewed?]
  {:path path :reviewed reviewed?})

(fn test-review-marks-persist-by-scope []
  (t.reset-workdir)
  (let [store (reviews.load-store)
        scope (reviews.scope "/repo" "main...HEAD")
        entries [(entry "a.rb" true) (entry "b.rb" false)]]
    (faith.is (reviews.persist store scope entries))
    (let [loaded (reviews.load-store)]
      (faith.= {"a.rb" true} (reviews.marks loaded scope))
      (faith.= {} (reviews.marks loaded "other-scope")))))

(fn test-apply-restores-reviewed-paths []
  (let [entries [(entry "a.rb" false) (entry "b.rb" false)]]
    (faith.= [(entry "a.rb" true) (entry "b.rb" false)]
             (reviews.apply entries {"a.rb" true}))))

{: test-apply-restores-reviewed-paths : test-review-marks-persist-by-scope}
