(local fennel-command (require :platform.fennel))
(local plan (require :preview.focus-plan))
(local sys (require :platform.core))
(local warm (require :preview.warm))

(import-macros {: set-fields} :state.macros)

(local boot-seconds 10)
(local check-seconds 2)
(local max-restarts 1)
(local import-budget 0.004)

(fn new-state []
  {:dir nil
   :src-dir nil
   :parent-pid nil
   :pid nil
   :seq 0
   :pending nil
   :next-response 1
   :started-at 0
   :checked-at 0
   :restarts 0
   :unavailable? false})

(fn server-command [src-dir dir parent-pid]
  (fennel-command.command src-dir :preview/focus-worker.fnl
                          [dir (or parent-pid "")]))

(fn available? [?state]
  (if (and ?state ?state.dir (not ?state.unavailable?))
      true
      false))

(fn spawn [state now]
  (let [dir (sys.make-temp-dir)]
    (when (and dir (sys.write-file (plan.alive-path dir) ""))
      (sys.background-command (server-command state.src-dir dir
                                              state.parent-pid))
      (set-fields state [:dir dir] [:pid nil] [:pending nil] [:next-response 1]
                  [:started-at now] [:checked-at now])
      true)))

(fn start [state src-dir ?parent-pid]
  (when (and (not state.dir) (not state.unavailable?))
    (set-fields state [:src-dir src-dir] [:parent-pid ?parent-pid])
    (when (not (spawn state (os.time)))
      (set state.unavailable? true))))

(fn cleanup [state]
  (when state.dir
    (sys.remove-dir state.dir))
  (set-fields state [:dir nil] [:pid nil] [:pending nil]))

(fn request [state wanted settings]
  (when (and (available? state) (plan.needs-request? state.pending wanted))
    (let [seq (+ state.seq 1)]
      (set state.seq seq)
      (when (sys.write-data-file (plan.request-path state.dir)
                                 (plan.request seq wanted settings))
        (set state.pending {:id wanted.id :generation wanted.generation})
        true))))

(fn server-pid [state]
  (when (not state.pid)
    (set state.pid
         (tonumber (or (sys.read-file (plan.ready-path state.dir)) ""))))
  state.pid)

(fn healthy? [state now]
  (case (server-pid state)
    pid (sys.process-alive? pid)
    _ (< (- now state.started-at) boot-seconds)))

(fn check-health [state now]
  (when (and (available? state) (<= check-seconds (- now state.checked-at)))
    (set state.checked-at now)
    (when (not (healthy? state now))
      (cleanup state)
      (if (and (< state.restarts max-restarts) (spawn state now))
          (set state.restarts (+ state.restarts 1))
          (set state.unavailable? true)))))

(fn store-response [caches response]
  (if (= response.kind :listing)
      (when (and caches.listing (= nil (. caches.listing response.key)))
        (tset caches.listing response.key response.lines))
      (warm.store-output caches response.key response)))

(fn import-responses [state caches generation clock budget]
  (let [started (clock)]
    (var stored? false)
    (var done? false)
    (while (not done?)
      (let [path (plan.response-path state.dir state.next-response)
            (ok response) (sys.read-data-file path)]
        (if (= nil ok)
            (set done? true)
            (do
              (when (and ok (plan.accept? response generation))
                (store-response caches response)
                (set stored? true))
              (sys.remove-file path)
              (set state.next-response (+ state.next-response 1))
              (when (<= budget (- (clock) started))
                (set done? true))))))
    stored?))

(fn update [state caches generation ?opts]
  "Import the server's responses in order, dropping answers from an older
`generation`, then check that the server is still running. Returns true when a
response was stored."
  (let [stored? (and (available? state)
                     (import-responses state caches generation
                                       (or (?. ?opts :clock) os.clock)
                                       (or (?. ?opts :budget) import-budget)))]
    (check-health state (or (?. ?opts :now) (os.time)))
    stored?))

{: available?
 : cleanup
 : new-state
 : request
 : server-command
 : start
 : update}
