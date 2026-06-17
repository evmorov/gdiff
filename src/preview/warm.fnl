(local fennel (require :fennel))
(local fennel-command (require :platform.fennel))
(local preview-key (require :preview.key))
(local plan (require :preview.warm_plan))
(local sys (require :platform.core))

(import-macros {: set-fields} :state.macros)

(local missing-entries plan.missing-entries)
(local side-priority-entries plan.side-priority-entries)

(fn make-dir []
  (let [path (sys.temp-path)]
    (sys.remove-file path)
    (when (sys.ensure-dir path)
      path)))

(fn output-path [dir index]
  (.. dir "/" index ".fnl"))

(fn manifest-path [dir]
  (.. dir "/manifest.fnl"))

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
  (set-fields state [:dir nil] [:count 0] [:remaining 0] [:workers 0]
              [:scan-index 1] [:imported {}] [:key-index {}] [:index-key {}]))

(fn write-manifest [path revision entries]
  (sys.write-file path (fennel.view {:revision revision :entries entries})))

(fn start-workers [src-dir manifest dir count]
  (for [i 1 count]
    (sys.background-command (worker-command src-dir manifest dir i count))))

(fn reset-for-run [state dir entries key-index index-key]
  (set-fields state [:dir dir] [:count (length entries)]
              [:remaining (length entries)] [:workers 0] [:scan-index 1]
              [:imported {}] [:key-index key-index] [:index-key index-key]))

(fn start-run [state src-dir revision entries dir]
  (let [manifest (manifest-path dir)]
    (when (write-manifest manifest revision entries)
      (let [(key-index index-key) (plan.index-entries revision entries)
            workers (plan.worker-count entries (sys.cpu-count))]
        (reset-for-run state dir entries key-index index-key)
        (set state.workers workers)
        (if (< 0 workers)
            (do
              (start-workers src-dir manifest dir workers)
              true)
            (cleanup state))))))

(fn start [state src-dir revision entries]
  (cleanup state)
  (when (< 0 (length entries))
    (let [dir (make-dir)]
      (when dir
        (when (not (start-run state src-dir revision entries dir))
          (cleanup state))))))

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
 : worker-command}
