(local focus-plan (require :preview.focus-plan))
(local format (require :preview.format))
(local preview (require :preview.core))
(local sys (require :platform.core))
(local worker-state (require :preview.worker-state))

(local poll-seconds 0.03)
(local parent-check-seconds 2)

(fn without-blame [settings]
  (doto (collect [k v (pairs settings)]
          (values k v))
    (tset :blame? false)))

(fn handle-entry [request emit]
  (let [settings request.settings
        entry request.target
        lines-state (worker-state.from-settings (without-blame settings))
        data (preview.warm-entry lines-state entry)]
    (emit (focus-plan.response request data))
    (when (and settings.blame? data.refs)
      (let [blame-state (worker-state.from-settings settings)
            blame (preview.warm-blame blame-state entry data.refs data.split)]
        (emit (focus-plan.response request {: blame}))))))

(fn handle-listing [request emit]
  (let [state (worker-state.from-settings request.settings)
        data (preview.listing-data state request.target.path)]
    (emit (focus-plan.response request data))))

(fn handle [request emit]
  (case request.kind
    :entry (handle-entry request emit)
    :listing (handle-listing request emit)))

(fn failure-response [request err]
  (let [state (worker-state.from-settings request.settings)]
    (focus-plan.response request {:lines (format.warning state (tostring err))
                                  :numbers false
                                  :refs false
                                  :split []})))

(fn run-request [request emit]
  (let [(ok err) (pcall handle request emit)]
    (when (not ok)
      (emit (failure-response request err)))))

(fn take-request [path claimed]
  "Move the request out of the slot and read it back, so a request the app
writes meanwhile is kept for the next poll."
  (when (sys.rename path claimed)
    (let [(ok request) (sys.read-data-file claimed)]
      (sys.remove-file claimed)
      (when ok
        request))))

(fn claim [dir ?seen-seq]
  "Take the waiting request once it has stayed the same for one poll. Returns
the claimed request, or nil and the seq of the request still waiting."
  (let [path (focus-plan.request-path dir)
        (ok request) (sys.read-data-file path)]
    (if (not ok) nil (not (focus-plan.claimable? ?seen-seq request))
        (values nil request.seq)
        (take-request path (focus-plan.claimed-path dir)))))

(fn parent-gone? [parent-pid]
  (and parent-pid (not (sys.process-alive? parent-pid))))

(fn serve [dir parent-pid]
  (var seen nil)
  (var sent 0)
  (var checked-at (os.time))
  (var running? true)

  (fn emit [response]
    (set sent (+ sent 1))
    (sys.write-data-file (focus-plan.response-path dir sent) response))

  (sys.write-file (focus-plan.ready-path dir)
                  (tostring (or (sys.process-id) "")))
  (while running?
    (let [now (os.time)]
      (if (not (sys.file-exists? (focus-plan.alive-path dir)))
          (set running? false)
          (<= parent-check-seconds (- now checked-at))
          (do
            (set checked-at now)
            (when (parent-gone? parent-pid)
              (set running? false)))
          (let [(request seq) (claim dir seen)]
            (set seen seq)
            (if request
                (run-request request emit)
                (sys.sleep poll-seconds)))))))

{: claim : handle : run-request : serve}
