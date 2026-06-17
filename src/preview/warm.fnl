(local fennel (require :fennel))
(local fennel-command (require :platform.fennel))
(local preview-key (require :preview.key))
(local sys (require :platform.core))

(fn make-dir []
  (let [path (sys.temp-path)]
    (sys.remove-file path)
    (when (sys.ensure-dir path)
      path)))

(fn output-path [dir index]
  (.. dir "/" index ".fnl"))

(fn manifest-path [dir]
  (.. dir "/manifest.fnl"))

(local max-workers 6)
(local edge-batch-size 8)
(local max-checks-per-update 64)
(local max-imports-per-update 8)

(fn worker-command [src-dir manifest dir start step]
  (fennel-command.command src-dir :preview/worker.fnl [manifest dir start step]))

(fn new-state []
  {:dir nil
   :count 0
   :remaining 0
   :workers 0
   :scan-index 1
   :imported {}
   :key-index {}
   :index-key {}})

(fn cleanup [state]
  (when state.dir
    (sys.remove-dir state.dir))
  (set state.dir nil)
  (set state.count 0)
  (set state.remaining 0)
  (set state.workers 0)
  (set state.scan-index 1)
  (set state.imported {})
  (set state.key-index {})
  (set state.index-key {}))

(fn write-manifest [path revision entries]
  (sys.write-file path (fennel.view {:revision revision :entries entries})))

(fn missing-entries [revision entries cache]
  (let [cache (or cache {})]
    (icollect [_ entry (ipairs entries)]
      (when (not (. cache (preview-key.for-entry revision entry)))
        entry))))

(fn side-priority-entries [entries ?batch-size]
  (let [batch-size (or ?batch-size edge-batch-size)
        out []]
    (var left 1)
    (var right (length entries))
    (while (<= left right)
      (var front-count 0)
      (while (and (<= left right) (< front-count batch-size))
        (table.insert out (. entries left))
        (set left (+ left 1))
        (set front-count (+ front-count 1)))
      (var back-count 0)
      (while (and (<= left right) (< back-count batch-size))
        (table.insert out (. entries right))
        (set right (- right 1))
        (set back-count (+ back-count 1))))
    out))

(fn index-entries [revision entries]
  (let [indexes {}
        keys {}]
    (each [i entry (ipairs entries)]
      (let [entry-key (preview-key.for-entry revision entry)]
        (tset indexes entry-key i)
        (tset keys i entry-key)))
    (values indexes keys)))

(fn cpu-worker-budget [?cpu-count]
  (let [cpus (or ?cpu-count (sys.cpu-count))]
    (if (<= cpus 2) 1
        (<= cpus 4) 2
        (<= cpus 8) 3
        (<= cpus 12) 4
        max-workers)))

(fn entry-worker-budget [count]
  (if (<= count 1) 1
      (< count 8) 2
      (< count 32) 3
      max-workers))

(fn worker-count [entries ?cpu-count]
  (let [count (length entries)]
    (if (<= count 0) 0
        (math.min count (cpu-worker-budget ?cpu-count)
                  (entry-worker-budget count)))))

(fn start-workers [src-dir manifest dir count]
  (for [i 1 count]
    (sys.background-command (worker-command src-dir manifest dir i count))))

(fn start [state src-dir revision entries]
  (cleanup state)
  (when (< 0 (length entries))
    (let [dir (make-dir)]
      (when dir
        (let [manifest (manifest-path dir)]
          (when (write-manifest manifest revision entries)
            (let [(key-index index-key) (index-entries revision entries)]
              (set state.key-index key-index)
              (set state.index-key index-key))
            (set state.dir dir)
            (set state.count (length entries))
            (set state.remaining (length entries))
            (set state.workers 0)
            (set state.scan-index 1)
            (set state.imported {})
            (let [workers (worker-count entries)]
              (set state.workers workers)
              (if (< 0 workers)
                  (start-workers src-dir manifest dir workers)
                  (cleanup state)))))))))

(fn read-lines [path]
  (let [source (sys.read-file path)]
    (when source
      (let [(ok result) (pcall fennel.eval source
                               {:filename path :allowedGlobals []})]
        (when ok
          result)))))

(fn remaining [state]
  (or state.remaining (- state.count (length state.imported))))

(fn mark-imported [state index]
  (when (not (. state.imported index))
    (tset state.imported index true)
    (set state.remaining (- (remaining state) 1))))

(fn advance-scan-index [state]
  (set state.scan-index
       (if (>= (or state.scan-index 1) state.count)
           1
           (+ (or state.scan-index 1) 1))))

(fn import-output [state cache index]
  (let [path (output-path state.dir index)
        lines (read-lines path)]
    (when lines
      (let [key (. state.index-key index)]
        (when key
          (tset cache key lines)))
      (sys.remove-file path)
      (mark-imported state index)
      true)))

(fn finish-if-complete [state]
  (when (and state.dir (<= (remaining state) 0))
    (cleanup state)))

(fn import-entry [state cache revision entry]
  (when (and state.dir entry)
    (let [key (preview-key.for-entry revision entry)
          index (. state.key-index key)]
      (when index
        (let [imported? (import-output state cache index)]
          (finish-if-complete state)
          imported?)))))

(fn update [state cache]
  (when state.dir
    (when (not state.imported)
      (set state.imported {}))
    (set state.remaining (remaining state))
    (var checks 0)
    (var imports 0)
    (let [max-checks (math.min state.count max-checks-per-update)]
      (while (and (< checks max-checks) (< imports max-imports-per-update)
                  (< 0 (remaining state)))
        (let [index (or state.scan-index 1)]
          (when (not (. state.imported index))
            (when (import-output state cache index)
              (set imports (+ imports 1))))
          (advance-scan-index state)
          (set checks (+ checks 1))))))
  (finish-if-complete state))

{: cleanup
 : import-entry
 : missing-entries
 : new-state
 : side-priority-entries
 : start
 : update
 : worker-count
 : worker-command}
