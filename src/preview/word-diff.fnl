(local txt (require :tui.text))

(fn tokenize [s]
  (let [out []
        len (length s)]
    (var i 1)
    (while (<= i len)
      (let [(_ ws-e) (s:find "^%s+" i)]
        (if ws-e
            (do
              (table.insert out
                            {:start i :stop (+ ws-e 1) :text (s:sub i ws-e)})
              (set i (+ ws-e 1)))
            (let [(_ w-e) (s:find "^[%w_]+" i)]
              (if w-e
                  (do
                    (table.insert out
                                  {:start i
                                   :stop (+ w-e 1)
                                   :text (s:sub i w-e)})
                    (set i (+ w-e 1)))
                  (let [(ch nxt) (txt.next-char s i)]
                    (table.insert out {:start i :stop nxt :text (or ch "")})
                    (set i nxt)))))))
    out))

(fn common-prefix [a b]
  (let [limit (math.min (length a) (length b))]
    (var n 0)
    (while (and (< n limit) (= (. a (+ n 1) :text) (. b (+ n 1) :text)))
      (set n (+ n 1)))
    n))

(fn common-suffix [a b prefix]
  (let [limit (- (math.min (length a) (length b)) prefix)]
    (var n 0)
    (while (and (< n limit)
                (= (. a (- (length a) n) :text) (. b (- (length b) n) :text)))
      (set n (+ n 1)))
    n))

(fn trim [s from to]
  (var f from)
  (var t to)
  (while (and (< f t) (string.match (s:sub f f) "%s"))
    (set f (+ f 1)))
  (while (and (< f t) (string.match (s:sub (- t 1) (- t 1)) "%s"))
    (set t (- t 1)))
  (if (< f t) (values f t) (values from to)))

(fn span-for [s tokens prefix suffix]
  (let [last (- (length tokens) suffix)]
    (when (> last prefix)
      (let [(from to) (trim s (. tokens (+ prefix 1) :start)
                            (. tokens last :stop))]
        {: from : to}))))

(fn spans [old new]
  (if (or (not old) (not new) (= old new))
      {}
      (let [a (tokenize old)
            b (tokenize new)
            prefix (common-prefix a b)
            suffix (common-suffix a b prefix)]
        {:old (span-for old a prefix suffix)
         :new (span-for new b prefix suffix)})))

{: spans}
