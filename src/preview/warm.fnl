(local fennel-command (require :platform.fennel))
(local plan (require :preview.warm-plan))
(local sys (require :platform.core))

(import-macros {: set-fields} :state.macros)

(local missing-entries plan.missing-entries)
(local side-priority-entries plan.side-priority-entries)

(fn manifest-path [dir]
  (.. dir "/manifest.lua"))

(local max-checks-per-update 64)

(local import-budget 0.007)

(fn worker-command [src-dir manifest dir start step]
  (sys.low-priority-command (fennel-command.command src-dir :preview/worker.fnl
                                                    [manifest dir start step])))

(fn new-state []
  {:dir nil
   :settings nil
   :blame? false
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
  (set-fields state [:dir nil] [:settings nil] [:blame? false] [:count 0]
              [:remaining 0] [:workers 0] [:scan-index 1] [:imported {}]
              [:key-index {}] [:index-key {}]))

(fn write-manifest [path entries settings]
  (sys.write-data-file path {: entries : settings}))

(fn start-workers [src-dir manifest dir count]
  (for [i 1 count]
    (sys.background-command (worker-command src-dir manifest dir i count))))

(fn reset-for-run [state dir entries key-index index-key settings]
  (set-fields state [:dir dir] [:settings settings]
              [:blame? (and settings.blame? true)] [:count (length entries)]
              [:remaining (length entries)] [:workers 0] [:scan-index 1]
              [:imported {}] [:key-index key-index] [:index-key index-key]))

(fn start-run [state src-dir entries dir settings]
  (let [manifest (manifest-path dir)]
    (when (write-manifest manifest entries settings)
      (let [(key-index index-key) (plan.index-entries settings entries)
            workers (plan.worker-count entries (sys.cpu-count))]
        (reset-for-run state dir entries key-index index-key settings)
        (set state.workers workers)
        (if (< 0 workers)
            (do
              (start-workers src-dir manifest dir workers)
              true)
            (cleanup state))))))

(fn start [state src-dir entries settings]
  "Start a background run for `entries`, rendered with `settings` from
`preview.core/background-settings`."
  (cleanup state)
  (when (< 0 (length entries))
    (let [dir (sys.make-temp-dir)]
      (when dir
        (when (not (start-run state src-dir entries dir settings))
          (cleanup state))))))

(fn remaining [state]
  (or state.remaining 0))

(fn mark-imported [state index]
  (when (not (. state.imported index))
    (tset state.imported index true)
    (set state.remaining (- (remaining state) 1))))

(fn advance-scan-index [state]
  (set state.scan-index
       (if (>= (or state.scan-index 1) state.count)
           1
           (+ (or state.scan-index 1) 1))))

;; Keep a value that is already cached, so tables the display and search caches
;; hold on to stay the same when a second source delivers the same key.
(fn store-into [?cache key value]
  (when (and ?cache (not= nil value) (= nil (. ?cache key)))
    (tset ?cache key value)))

(fn store-output [caches key data]
  "Copy one worker output into the app caches. `caches` has `lines` and may
have `split`, `numbers`, `refs`, and `blame` tables."
  (store-into caches.lines key data.lines)
  (store-into caches.split (.. key "\0split") data.split)
  (store-into caches.numbers key data.numbers)
  (store-into caches.refs key data.refs)
  (when data.blame
    (each [blame-key blame-lines (pairs data.blame)]
      (store-into caches.blame blame-key blame-lines))))

(fn import-output [state caches index]
  "Import the output for `index` when a worker has written it. An output that
cannot be loaded is dropped, so the run still finishes."
  (let [path (plan.output-path state.dir index)
        (ok data) (sys.read-data-file path)]
    (when (not= nil ok)
      (let [key (. state.index-key index)]
        (when (and ok key (= (type data) :table))
          (store-output caches key data)))
      (sys.remove-file path)
      (mark-imported state index)
      ok)))

(fn finish-if-complete [state]
  (when (and state.dir (<= (remaining state) 0))
    (cleanup state)))

(fn import-key [state caches key]
  (when (and state.dir key)
    (let [index (. state.key-index key)]
      (when index
        (let [imported? (import-output state caches index)]
          (finish-if-complete state)
          imported?)))))

(fn within-budget? [opts started imports]
  (or (= imports 0) (< (- (opts.clock) started) opts.budget)))

(fn update [state caches ?opts]
  "Import finished worker output into the caches until the CPU budget in
`?opts` is spent. Returns true when at least one entry was imported."
  (let [opts {:clock (or (?. ?opts :clock) os.clock)
              :budget (or (?. ?opts :budget) import-budget)}
        started (opts.clock)]
    (var imports 0)
    (when state.dir
      (var checks 0)
      (let [max-checks (math.min state.count max-checks-per-update)]
        (while (and (< checks max-checks) (< 0 (remaining state))
                    (within-budget? opts started imports))
          (let [index (or state.scan-index 1)]
            (when (not (. state.imported index))
              (when (import-output state caches index)
                (set imports (+ imports 1))))
            (advance-scan-index state)
            (set checks (+ checks 1))))))
    (finish-if-complete state)
    (< 0 imports)))

{: cleanup
 : import-key
 : missing-entries
 : new-state
 : side-priority-entries
 : start
 : store-output
 : update
 : worker-command}
