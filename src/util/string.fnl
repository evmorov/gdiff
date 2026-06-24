(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn contains? [text query]
  (let [text (or text "")]
    (not (= nil (text:find query 1 true)))))

{: contains? : trim}
