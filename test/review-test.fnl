(local faith (require :faith))
(local review (require :app.review))

(fn entry [reviewed?]
  {:reviewed reviewed?})

(fn test-count-and-all []
  (faith.= 0 (review.count []))
  (faith.= false (review.all? []))
  (faith.= 1 (review.count [(entry true) (entry false)]))
  (faith.= false (review.all? [(entry true) (entry false)]))
  (faith.= true (review.all? [(entry true) (entry true)])))

(fn test-toggle-all-marks-or-unmarks-all []
  (let [entries [(entry false) (entry true)]]
    (faith.= true (review.toggle-all! entries))
    (faith.= [true true] [(. entries 1 :reviewed) (. entries 2 :reviewed)])
    (faith.= false (review.toggle-all! entries))
    (faith.= [false false] [(. entries 1 :reviewed) (. entries 2 :reviewed)])))

(fn test-toggle-entry []
  (let [entry (entry false)]
    (faith.= true (review.toggle-entry! entry))
    (faith.= true entry.reviewed)
    (faith.= false (review.toggle-entry! entry))
    (faith.= false entry.reviewed)))

{: test-count-and-all
 : test-toggle-all-marks-or-unmarks-all
 : test-toggle-entry}
