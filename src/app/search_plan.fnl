(fn new-state []
  {:active? false :query "" :matches [] :index 0})

(fn start []
  {:active? true :query "" :matches [] :index 0})

(fn finish [search]
  {:active? false
   :query (or search.query "")
   :matches (or search.matches [])
   :index (or search.index 0)})

(fn clear []
  (new-state))

(fn backspace-query [query]
  (let [query (or query "")
        len (length query)]
    (if (> len 0)
        (query:sub 1 (- len 1))
        query)))

(fn append-query [query key]
  (.. (or query "") key))

(fn printable? [key]
  (and (= (type key) "string") (= (length key) 1)
       (let [byte (string.byte key)]
         (and byte (>= byte 32) (not (= byte 127))))))

{: append-query
 : backspace-query
 : clear
 : finish
 : new-state
 : printable?
 : start}
