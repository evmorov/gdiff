(local str (require :util.string))

(local max-name 8)

(fn first-name [author]
  (str.crop (or (and author (author:match "^(%S+)")) author "") max-name))

(fn date [timestamp]
  (if timestamp
      (os.date "%d/%m/%Y" timestamp)
      ""))

(fn label [entry]
  (let [d (date entry.time)
        author (first-name entry.author)]
    (if (> (length author) 0) (.. d " " author) d)))

(fn parse [output]
  (let [lines {}]
    (var current nil)
    (each [line (string.gmatch (or output "") "[^\r\n]+")]
      (let [(_orig final) (line:match "^%S+ (%d+) (%d+) ?%d*$")]
        (if final
            (set current {:line (tonumber final)})
            (and current (line:match "^author "))
            (set current.author (line:sub 8))
            (and current (line:match "^author%-time "))
            (set current.time (tonumber (line:sub 13)))
            (and current (= (line:sub 1 1) "\t"))
            (do
              (when current.line
                (tset lines current.line (label current)))
              (set current nil)))))
    lines))

(fn sorted-line-numbers [lines]
  (let [seen {}
        out []]
    (each [_ n (ipairs (or lines []))]
      (when (and n (not (. seen n)))
        (tset seen n true)
        (table.insert out n)))
    (table.sort out)
    out))

(fn ranges [lines]
  "Merge line numbers into sorted, contiguous [from to] ranges for git blame -L."
  (let [out []]
    (var from nil)
    (var to nil)
    (each [_ n (ipairs (sorted-line-numbers lines))]
      (if (not from) (do
                       (set from n) (set to n))
          (= n (+ to 1)) (set to n)
          (do
            (table.insert out [from to])
            (set from n)
            (set to n))))
    (when from (table.insert out [from to]))
    out))

{: parse : ranges}
