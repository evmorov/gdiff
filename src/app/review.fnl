(fn count [entries]
  (accumulate [total 0 _ entry (ipairs (or entries []))]
    (if entry.reviewed (+ total 1) total)))

(fn all? [entries]
  (let [total (length (or entries []))]
    (and (< 0 total) (= total (count entries)))))

(fn set-all! [entries reviewed?]
  (each [_ entry (ipairs (or entries []))]
    (set entry.reviewed reviewed?))
  entries)

(fn toggle-all! [entries]
  (let [review? (not (all? entries))]
    (set-all! entries review?)
    review?))

(fn toggle-entry! [entry]
  (when entry
    (set entry.reviewed (not entry.reviewed))
    entry.reviewed))

{: all? : count : set-all! : toggle-all! : toggle-entry!}
