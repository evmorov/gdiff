(local max-workers 6)

(fn cpu-budget [?cpu-count]
  (let [cpus (or ?cpu-count 1)]
    (if (<= cpus 2) 1
        (<= cpus 4) 2
        (<= cpus 8) 3
        (<= cpus 12) 4
        max-workers)))

(fn entry-budget [count]
  (if (<= count 1) 1
      (< count 8) 2
      (< count 32) 3
      max-workers))

(fn count [entries ?cpu-count]
  (let [entry-count (length entries)]
    (if (<= entry-count 0) 0
        (math.min entry-count (cpu-budget ?cpu-count)
                  (entry-budget entry-count)))))

{: count : cpu-budget : entry-budget :max max-workers}
