(local txt (require :tui.text))

(fn match-ranges [plain query]
  (let [ranges []]
    (when (< 0 (length query))
      (var start 1)
      (var searching? true)
      (while searching?
        (let [(first last) (plain:find query start true)]
          (if first
              (do
                (table.insert ranges {: first : last})
                (set start (+ last 1)))
              (set searching? false)))))
    ranges))

(fn apply [s ranges start-code end-code]
  (let [out []]
    (fn append [part]
      (table.insert out part))

    (var i 1)
    (var visible 1)
    (var range-index 1)
    (while (<= i (length s))
      (let [range (. ranges range-index)]
        (when (and range (= visible range.first))
          (append start-code))
        (if (txt.ansi-sequence? s i)
            (let [last (txt.ansi-sequence-end s i)]
              (append (s:sub i last))
              (set i (+ last 1)))
            (let [(ch next-i) (txt.next-char s i)]
              (append ch)
              (when (and range (= visible range.last))
                (append end-code)
                (set range-index (+ range-index 1)))
              (set visible (+ visible 1))
              (set i next-i)))))
    (table.concat out)))

(fn highlight [s query start-code end-code]
  (let [s (tostring (or s ""))
        ranges (match-ranges (txt.strip-ansi s) (or query ""))]
    (if (or (= (length ranges) 0) (not start-code))
        s
        (apply s ranges start-code end-code))))

{: apply : highlight : match-ranges}
