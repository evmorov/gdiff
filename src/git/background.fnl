;; Shared machinery for background git jobs that write their output to a
;; temp file which the app polls until the file appears.

(local sys (require :platform.core))

(fn new-state [fields]
  (let [state {:path (sys.temp-path) :running? false}]
    (each [k v (pairs (or fields {}))]
      (tset state k v))
    state))

(fn start [state can-start? spawn! payload]
  (when (and (not state.running?) (can-start? state))
    (set state.running? true)
    (spawn! state.path payload)
    true))

(fn poll [state finish!]
  (when state.running?
    (let [output (sys.read-file state.path)]
      (when output
        (set state.running? false)
        (sys.remove-file state.path)
        (finish! state output)))))

{: new-state : poll : start}
