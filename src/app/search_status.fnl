(local separator " │ ")

(fn plural [count singular plural-form]
  (if (= count 1) singular plural-form))

(fn active [query count]
  (.. "/" query separator count " " (plural count "match" "matches") separator
      "enter finish" separator "esc clear"))

(fn inactive [query index count]
  (when (> (length (or query "")) 0)
    (if (= count 0)
        (.. "No matches for '" query "'")
        (.. "Search: " index "/" count " " query separator "n/N next/prev"
            separator "q clear"))))

(fn notice [search]
  (let [count (length search.matches)]
    (if search.active?
        (active search.query count)
        (inactive search.query search.index count))))

(fn prompt [search]
  (if search.active?
      (active search.query (length search.matches))))

{: active : inactive : notice : prompt}
