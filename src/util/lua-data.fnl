(fn number-literal [n]
  (if (not= n n) (error "cannot serialize NaN")
      (or (= n math.huge) (= n (- math.huge))) (error "cannot serialize inf")
      (and math.type (= (math.type n) :integer)) (string.format "%d" n)
      (string.format "%.17g" n)))

(fn array-index? [key count]
  (and (= (type key) :number) (= key (math.floor key)) (<= 1 key count)))

(fn write-value [out value seen]
  (case (type value)
    :string (table.insert out (string.format "%q" value))
    :number (table.insert out (number-literal value))
    :boolean (table.insert out (tostring value))
    :nil (table.insert out :nil)
    :table (do
             (when (. seen value)
               (error "cannot serialize a table cycle"))
             (tset seen value true)
             (table.insert out "{")
             (let [count (length value)]
               (for [i 1 count]
                 (write-value out (. value i) seen)
                 (table.insert out ","))
               (each [key item (pairs value)]
                 (when (not (array-index? key count))
                   (table.insert out "[")
                   (write-value out key seen)
                   (table.insert out "]=")
                   (write-value out item seen)
                   (table.insert out ","))))
             (table.insert out "}")
             (tset seen value nil))
    other (error (.. "cannot serialize a " other))))

(fn serialize [value]
  (let [out ["return "]]
    (write-value out value {})
    (table.concat out)))

{: serialize}
