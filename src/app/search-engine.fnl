(local nav (require :app.search-nav))
(local search-plan (require :app.search-plan))
(local search-status (require :app.search-status))
(local tui (require :tui.core))

(fn get [ctx state]
  (ctx.get state))

(fn query [ctx state]
  (let [search (get ctx state)]
    (or (and search search.query) "")))

(fn active? [ctx state]
  (let [search (get ctx state)]
    (and search search.active?)))

(fn has-query? [ctx state]
  (> (length (query ctx state)) 0))

(fn set-status [ctx state]
  (set state.notice (search-status.notice (get ctx state))))

(fn first-index [ctx state matches]
  (nav.first-at-or-after (ctx.cursor-position state) matches))

(fn apply-match [ctx state found]
  (when found
    (ctx.apply state found)))

(fn jump-to [ctx state index]
  (let [search (get ctx state)
        count (length search.matches)]
    (when (> count 0)
      (let [index (if (< index 1) count
                      (> index count) 1
                      index)]
        (set search.index index)
        (apply-match ctx state (. search.matches index))))
    (set-status ctx state)))

(fn rebuild [ctx state ?preserve-selection?]
  (let [search (get ctx state)
        matches (ctx.collect state search.query)]
    (set search.matches matches)
    (set search.index 0)
    (if ?preserve-selection?
        (do
          (when (> (length matches) 0)
            (set search.index (first-index ctx state matches)))
          (set-status ctx state))
        (> (length matches) 0)
        (jump-to ctx state (first-index ctx state matches))
        (set-status ctx state))))

(fn start [ctx state]
  (ctx.set state (search-plan.start))
  (set-status ctx state))

(fn finish [ctx state]
  (ctx.set state (search-plan.finish (get ctx state)))
  (set-status ctx state))

(fn clear [ctx state]
  (ctx.set state (search-plan.clear))
  (set state.notice nil))

(fn backspace [ctx state]
  (let [search (get ctx state)]
    (set search.query (search-plan.backspace-query search.query))
    (rebuild ctx state)))

(fn append-char [ctx state key]
  (let [search (get ctx state)]
    (set search.query (search-plan.append-query search.query key)))
  (rebuild ctx state))

(fn handle-input [ctx state key]
  (case key
    :tick true
    :enter (do
             (finish ctx state)
             true)
    :escape (do
              (clear ctx state)
              true)
    "\127" (do
             (backspace ctx state)
             true)
    "\8" (do
           (backspace ctx state)
           true)
    _ (if (search-plan.printable? key)
          (do
            (append-char ctx state key)
            true)
          true)))

(fn next [ctx state]
  (let [search (get ctx state)]
    (jump-to ctx state (nav.first-after (ctx.cursor-position state)
                                        search.matches))))

(fn previous [ctx state]
  (let [search (get ctx state)]
    (jump-to ctx state (nav.last-before (ctx.cursor-position state)
                                        search.matches))))

(fn highlight [ctx state text]
  (if (has-query? ctx state)
      (tui.highlight-matches state.theme text (query ctx state))
      text))

(fn status [ctx state]
  (search-status.prompt (get ctx state)))

(fn refresh-status [ctx state]
  (set-status ctx state))

{: active?
 : clear
 : finish
 : handle-input
 : has-query?
 : highlight
 : jump-to
 : next
 : previous
 : query
 : rebuild
 : refresh-status
 : start
 : status}
