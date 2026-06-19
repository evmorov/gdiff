(local matcher (require :app.search-match))
(local nav (require :app.search-nav))
(local selection (require :app.selection))
(local search-plan (require :app.search-plan))
(local search-status (require :app.search-status))
(local tui (require :tui.core))

(fn new-state []
  (search-plan.new-state))

(fn search [state]
  state.search)

(fn query [state]
  (or (and state.search state.search.query) ""))

(fn active? [state]
  (and state.search state.search.active?))

(fn has-query? [state]
  (> (length (query state)) 0))

(fn cursor-position [state]
  (selection.cursor-position state))

(fn set-status [state]
  (set state.notice (search-status.notice (search state))))

(fn first-index [state matches]
  (nav.first-at-or-after (cursor-position state) matches))

(fn apply-match [state found]
  (when found
    (selection.set-match state found)))

(fn jump-to [state index]
  (let [search (search state)
        count (length search.matches)]
    (when (> count 0)
      (let [index (if (< index 1) count
                      (> index count) 1
                      index)]
        (set search.index index)
        (apply-match state (. search.matches index))))
    (set-status state)))

(fn next-index-from-selection [state matches]
  (nav.first-after (cursor-position state) matches))

(fn previous-index-from-selection [state matches]
  (nav.last-before (cursor-position state) matches))

(fn rebuild [state ?preserve-selection?]
  (let [search (search state)
        matches (matcher.collect-matches state search.query)]
    (set search.matches matches)
    (set search.index 0)
    (if ?preserve-selection?
        (do
          (when (> (length matches) 0)
            (set search.index (first-index state matches)))
          (set-status state))
        (> (length matches) 0)
        (jump-to state (first-index state matches))
        (set-status state))))

(fn start [state]
  (set state.search (search-plan.start))
  (set-status state))

(fn finish [state]
  (set state.search (search-plan.finish (search state)))
  (set-status state))

(fn clear [state]
  (set state.search (search-plan.clear))
  (set state.notice nil))

(fn backspace [state]
  (let [search (search state)]
    (set search.query (search-plan.backspace-query search.query))
    (rebuild state)))

(fn printable? [key]
  (search-plan.printable? key))

(fn append-char [state key]
  (set (. state.search :query)
       (search-plan.append-query state.search.query key))
  (rebuild state))

(fn handle-input [state key]
  (case key
    :tick true
    :enter (do
             (finish state)
             true)
    :escape (do
              (clear state)
              true)
    "\127" (do
             (backspace state)
             true)
    "\8" (do
           (backspace state)
           true)
    _ (if (printable? key)
          (do
            (append-char state key)
            true)
          true)))

(fn next [state]
  (let [search (search state)]
    (jump-to state (next-index-from-selection state search.matches))))

(fn previous [state]
  (let [search (search state)]
    (jump-to state (previous-index-from-selection state search.matches))))

(fn highlight [state text]
  (if (has-query? state)
      (tui.highlight-matches state.theme text (query state))
      text))

(fn status [state]
  (search-status.prompt (search state)))

{: active?
 : clear
 : handle-input
 : has-query?
 : highlight
 : new-state
 : next
 : previous
 : query
 : rebuild
 : start
 : status}
