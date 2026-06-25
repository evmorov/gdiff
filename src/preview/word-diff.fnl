(local txt (require :tui.text))
(local theme (require :tui.theme))
(local ansi (require :tui.ansi))

(fn tokenize [s]
  (let [out []
        len (length s)]
    (var i 1)
    (while (<= i len)
      (let [(_ ws-e) (s:find "^%s" i)]
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

(fn lcs-match [a b]
  (let [m (length a)
        n (length b)
        dp (fcollect [_ 0 m] (fcollect [_ 0 n] 0))]
    (for [i 1 m]
      (for [j 1 n]
        (tset (. dp (+ i 1)) (+ j 1)
              (if (= (. a i :text) (. b j :text))
                  (+ (. dp i j) (length (. a i :text)))
                  (math.max (. dp i (+ j 1)) (. dp (+ i 1) j))))))
    (let [ma (fcollect [_ 1 m]
               false)
          mb (fcollect [_ 1 n]
               false)]
      (var i m)
      (var j n)
      (while (and (> i 0) (> j 0))
        (let [cur (. dp (+ i 1) (+ j 1))
              up (. dp i (+ j 1))
              left (. dp (+ i 1) j)]
          (if (= left cur) (set j (- j 1)) (= up cur) (set i (- i 1))
              (do
                (tset ma i true)
                (tset mb j true)
                (set i (- i 1))
                (set j (- j 1))))))
      (values ma mb))))

(fn ranges-from [tokens matched]
  (let [out []
        len (length tokens)]
    (var i 1)
    (while (<= i len)
      (if (. matched i)
          (set i (+ i 1))
          (let [from (. tokens i :start)]
            (var j i)
            (while (and (<= j len) (not (. matched j)))
              (set j (+ j 1)))
            (table.insert out {: from :to (. tokens (- j 1) :stop)})
            (set i j))))
    out))

(fn spans [old new]
  (if (or (not old) (not new) (= old new))
      {:old [] :new []}
      (let [a (tokenize old)
            b (tokenize new)
            (ma mb) (lcs-match a b)]
        {:old (ranges-from a ma) :new (ranges-from b mb)})))

(local max-line-distance 0.6)

(local max-align-cells 10000)

(fn word-list [s]
  (icollect [_ t (ipairs (tokenize s))]
    (when (t.text:match "^[%w_]") t.text)))

(fn word-chars [words]
  (accumulate [sum 0 _ w (ipairs words)]
    (+ sum (length w))))

(fn lcs-chars [a b]
  (let [m (length a)
        n (length b)
        dp (fcollect [_ 0 m] (fcollect [_ 0 n] 0))]
    (for [i 1 m]
      (for [j 1 n]
        (tset (. dp (+ i 1)) (+ j 1)
              (if (= (. a i) (. b j))
                  (+ (. dp i j) (length (. a i)))
                  (math.max (. dp i (+ j 1)) (. dp (+ i 1) j))))))
    (. dp (+ m 1) (+ n 1))))

(fn word-distance [a b]
  (let [total (+ (word-chars a) (word-chars b))]
    (if (= total 0) 0 (- 1 (/ (* 2 (lcs-chars a b)) total)))))

(fn line-distance [a b]
  (word-distance (word-list a) (word-list b)))

(fn naive-align [m n allowed?]
  (let [pairs []]
    (for [i 1 (math.max m n)]
      (if (and (<= i m) (<= i n))
          (if (allowed? i i)
              (table.insert pairs {:old i :new i})
              (do
                (table.insert pairs {:old i})
                (table.insert pairs {:new i})))
          (<= i m)
          (table.insert pairs {:old i})
          (table.insert pairs {:new i})))
    pairs))

(fn dp-align [m n allowed? gain]
  (let [neg-inf (- math.huge)
        dp (fcollect [_ 0 m] (fcollect [_ 0 n] 0))]
    (for [i 1 m]
      (for [j 1 n]
        (let [up (. dp i (+ j 1))
              left (. dp (+ i 1) j)
              diag (if (allowed? i j) (+ (. dp i j) (gain i j)) neg-inf)]
          (tset (. dp (+ i 1)) (+ j 1) (math.max up left diag)))))
    (let [pairs []]
      (var i m)
      (var j n)
      (while (and (> i 0) (> j 0))
        (let [cur (. dp (+ i 1) (+ j 1))
              up (. dp i (+ j 1))
              diag (when (allowed? i j) (+ (. dp i j) (gain i j)))]
          (if (and diag (= cur diag))
              (do
                (table.insert pairs 1 {:old i :new j})
                (set i (- i 1))
                (set j (- j 1)))
              (= cur up)
              (do
                (table.insert pairs 1 {:old i})
                (set i (- i 1)))
              (do
                (table.insert pairs 1 {:new j})
                (set j (- j 1))))))
      (while (> i 0)
        (table.insert pairs 1 {:old i})
        (set i (- i 1)))
      (while (> j 0)
        (table.insert pairs 1 {:new j})
        (set j (- j 1)))
      pairs)))

(fn align [removed added]
  (let [m (length removed)
        n (length added)
        words-r (fcollect [i 1 m] (word-list (. removed i)))
        words-a (fcollect [j 1 n] (word-list (. added j)))
        dist (fn [i j] (word-distance (. words-r i) (. words-a j)))
        allowed? (fn [i j] (<= (dist i j) max-line-distance))]
    (if (or (= 0 (* m n)) (> (* m n) max-align-cells))
        (naive-align m n allowed?)
        (let [dmat (fcollect [i 1 m] (fcollect [j 1 n] (dist i j)))]
          (dp-align m n (fn [i j] (<= (. dmat i j) max-line-distance))
                    (fn [i j] (- 1 (. dmat i j))))))))

(fn emphasize [theme-table raw ?ranges style-key]
  (if (and ?ranges (next ?ranges) (ansi.color?))
      (let [start (theme.style-for theme-table style-key)
            stop (theme.style-for theme-table :emphasis-end)]
        (var out "")
        (var pos 1)
        (each [_ r (ipairs ?ranges)]
          (when (< r.from r.to)
            (set out (.. out (raw:sub pos (- r.from 1)) start
                         (raw:sub r.from (- r.to 1)) stop))
            (set pos r.to)))
        (.. out (raw:sub pos)))
      raw))

{: spans : emphasize : align : line-distance}
