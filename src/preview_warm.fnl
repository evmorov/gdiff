(local fennel (require :fennel))
(local preview-key (require :preview_key))
(local sys (require :sys))

(fn make-dir []
  (let [path (sys.temp-path)]
    (sys.remove-file path)
    (when (sys.ensure-dir path)
      path)))

(fn output-path [dir index]
  (.. dir "/" index ".fnl"))

(fn manifest-path [dir]
  (.. dir "/manifest.fnl"))

(local max-workers 4)
(local max-checks-per-update 64)
(local max-imports-per-update 8)

(fn worker-command [src-dir manifest dir start step]
  (.. "fennel --add-fennel-path " (sys.shell-quote (.. src-dir "/?.fnl")) " "
      (sys.shell-quote (.. src-dir "/preview_worker.fnl")) " "
      (sys.shell-quote manifest) " " (sys.shell-quote dir) " " start " " step))

(fn new-state []
  {:dir nil
   :count 0
   :remaining 0
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
  (set state.scan-index 1)
  (set state.imported {})
  (set state.key-index {})
  (set state.index-key {}))

(fn write-manifest [path revision entries]
  (sys.write-file path (fennel.view {:revision revision :entries entries})))

(fn index-entries [revision entries]
  (let [indexes {}
        keys {}]
    (each [i entry (ipairs entries)]
      (let [entry-key (preview-key.for-entry revision entry)]
        (tset indexes entry-key i)
        (tset keys i entry-key)))
    (values indexes keys)))

(fn worker-count [entries]
  (math.min max-workers (length entries)))

(fn start-workers [src-dir manifest dir count]
  (for [i 1 count]
    (sys.background-command (worker-command src-dir manifest dir i count))))

(fn start [state src-dir revision entries]
  (cleanup state)
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
          (set state.scan-index 1)
          (set state.imported {})
          (let [workers (worker-count entries)]
            (if (< 0 workers)
                (start-workers src-dir manifest dir workers)
                (cleanup state))))))))

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
  (when (and state.dir (<= (remaining state) 0))
    (cleanup state)))

{: new-state : start : update}
