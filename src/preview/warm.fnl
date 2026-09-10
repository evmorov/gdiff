(local fennel (require :fennel))
(local fennel-command (require :platform.fennel))
(local preview-key (require :preview.key))
(local plan (require :preview.warm-plan))
(local sys (require :platform.core))

(import-macros {: set-fields} :state.macros)

(local missing-entries plan.missing-entries)
(local side-priority-entries plan.side-priority-entries)

(fn make-dir []
  (let [path (sys.temp-path)]
    (sys.remove-file path)
    (when (sys.ensure-dir path)
      path)))

(fn manifest-path [dir]
  (.. dir "/manifest.fnl"))

(local max-checks-per-update 64)
(local max-imports-per-update 8)

(fn worker-command [src-dir manifest dir start step]
  (fennel-command.command src-dir :preview/worker.fnl [manifest dir start step]))

(fn new-state []
  {:dir nil
   :blame? false
   :count 0
   :remaining 0
   :workers 0
   :scan-index 1
   :imported {}
   :key-index {}
   :index-key {}
   :highlight? false})

(fn cleanup [state]
  (when state.dir
    (sys.remove-dir state.dir))
  (set-fields state [:dir nil] [:blame? false] [:count 0] [:remaining 0]
              [:workers 0] [:scan-index 1] [:imported {}] [:key-index {}]
              [:index-key {}] [:highlight? false]))

(fn write-manifest [path
                    revision
                    entries
                    ?old-label
                    ?new-label
                    ?blame?
                    ?highlight]
  (sys.write-file path
                  (fennel.view {: revision
                                : entries
                                :old-label ?old-label
                                :new-label ?new-label
                                :blame? (and ?blame? true)
                                :highlight ?highlight})))

(fn start-workers [src-dir manifest dir count]
  (for [i 1 count]
    (sys.background-command (worker-command src-dir manifest dir i count))))

(fn reset-for-run [state dir entries key-index index-key ?blame? ?highlight?]
  (set-fields state [:dir dir] [:blame? (and ?blame? true)]
              [:count (length entries)] [:remaining (length entries)]
              [:workers 0] [:scan-index 1] [:imported {}] [:key-index key-index]
              [:index-key index-key] [:highlight? (and ?highlight? true)]))

(fn start-run [state
               src-dir
               revision
               entries
               dir
               ?old-label
               ?new-label
               ?blame?
               ?highlight]
  (let [manifest (manifest-path dir)]
    (when (write-manifest manifest revision entries ?old-label ?new-label
                          ?blame? ?highlight)
      (let [highlight? (and ?highlight ?highlight.on? true)
            (key-index index-key) (plan.index-entries revision entries
                                                      highlight?)
            workers (plan.worker-count entries (sys.cpu-count))]
        (reset-for-run state dir entries key-index index-key ?blame? highlight?)
        (set state.workers workers)
        (if (< 0 workers)
            (do
              (start-workers src-dir manifest dir workers)
              true)
            (cleanup state))))))

(fn start [state
           src-dir
           revision
           entries
           ?old-label
           ?new-label
           ?blame?
           ?highlight]
  "Start a background run for `entries`. With `?blame?`, workers also blame
each entry so the blame gutters fill without blocking. `?highlight` carries the
syntax highlighting settings and terminal background the workers render with."
  (cleanup state)
  (when (< 0 (length entries))
    (let [dir (make-dir)]
      (when dir
        (when (not (start-run state src-dir revision entries dir ?old-label
                              ?new-label ?blame? ?highlight))
          (cleanup state))))))

(fn read-output [path]
  (let [(ok result) (fennel-command.load-file path)]
    (when ok
      result)))

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

(fn store-into [?cache key value]
  (when (and ?cache (not= nil value))
    (tset ?cache key value)))

(fn store-output [caches key data]
  "Copy one worker output into the app caches. `caches` has `lines` and may
have `split`, `numbers`, `refs`, and `blame` tables."
  (tset caches.lines key data.lines)
  (store-into caches.split (.. key "\0split") data.split)
  (store-into caches.numbers key data.numbers)
  (store-into caches.refs key data.refs)
  (when (and caches.blame data.blame)
    (each [blame-key blame-lines (pairs data.blame)]
      (tset caches.blame blame-key blame-lines))))

(fn import-output [state caches index]
  (let [path (plan.output-path state.dir index)
        data (read-output path)]
    (when data
      (let [key (. state.index-key index)]
        (when key
          (store-output caches key data)))
      (sys.remove-file path)
      (mark-imported state index)
      true)))

(fn finish-if-complete [state]
  (when (and state.dir (<= (remaining state) 0))
    (cleanup state)))

(fn import-entry [state caches revision entry]
  (when (and state.dir entry)
    (let [key (preview-key.for-entry revision entry nil nil state.highlight?)
          index (. state.key-index key)]
      (when index
        (let [imported? (import-output state caches index)]
          (finish-if-complete state)
          imported?)))))

(fn update [state caches]
  (when state.dir
    (var checks 0)
    (var imports 0)
    (let [max-checks (math.min state.count max-checks-per-update)]
      (while (and (< checks max-checks) (< imports max-imports-per-update)
                  (< 0 (remaining state)))
        (let [index (or state.scan-index 1)]
          (when (not (. state.imported index))
            (when (import-output state caches index)
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
