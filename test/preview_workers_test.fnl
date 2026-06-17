(local faith (require :faith))
(local workers (require :preview.workers))

(fn entry [path]
  {:path path})

(fn entries [count]
  (fcollect [i 1 count]
    (entry (.. i ".rb"))))

(fn test-worker-count-scales-with-cpu-and-entry-count []
  (faith.= 0 (workers.count [] 8))
  (faith.= 1 (workers.count (entries 1) 8))
  (faith.= 2 (workers.count (entries 6) 8))
  (faith.= 3 (workers.count (entries 20) 8))
  (faith.= 2 (workers.count (entries 100) 4))
  (faith.= 6 (workers.count (entries 100) 16)))

(fn test-worker-budgets-are-capped []
  (faith.= 1 (workers.cpu-budget 2))
  (faith.= 2 (workers.cpu-budget 4))
  (faith.= 3 (workers.cpu-budget 8))
  (faith.= 4 (workers.cpu-budget 12))
  (faith.= workers.max (workers.cpu-budget 64)))

{: test-worker-budgets-are-capped
 : test-worker-count-scales-with-cpu-and-entry-count}
