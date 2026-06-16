(local entry-view (require :entry))
(local preview (require :preview))
(local tui (require :tui))

(fn new-state []
  {:active? false :query "" :matches [] :index 0})

(fn search [state]
  state.search)

(fn query [state]
  (or (and state.search state.search.query) ""))

(fn active? [state]
  (and state.search state.search.active?))

(fn has-query? [state]
  (> (length (query state)) 0))

(fn contains? [text query]
  (let [plain (tui.strip-ansi text)]
    (not (= nil (plain:find query 1 true)))))

(fn path-match [query entry-index entry]
  (if (contains? (entry-view.path-text entry) query)
      {:entry entry-index}))

(fn collect-matches [state query]
  (let [matches []]
    (when (> (length query) 0)
      (each [entry-index entry (ipairs state.entries)]
        (let [found (path-match query entry-index entry)]
          (when found
            (table.insert matches found)))))
    matches))

(fn first-index [state matches]
  (var index 1)
  (var found? false)
  (each [i found (ipairs matches)]
    (when (and (not found?) (>= found.entry state.selected))
      (set index i)
      (set found? true)))
  index)

(fn set-status [state]
  (let [search (search state)
        count (length search.matches)]
    (set state.notice
         (if search.active?
             (.. "/" search.query " | " count " match" (if (= count 1) "" "es")
                 " | enter finish | esc clear")
             (and (> (length search.query) 0)
                  (if (= count 0)
                      (.. "No matches for '" search.query "'")
                      (.. "Search: " search.index "/" count " " search.query
                          " | n/N next/prev | q clear")))))))

(fn apply-match [state found]
  (when found
    (set state.selected found.entry)
    (preview.reset-scroll state)))

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

(fn rebuild [state]
  (let [search (search state)
        matches (collect-matches state search.query)]
    (set search.matches matches)
    (set search.index 0)
    (if (> (length matches) 0)
        (jump-to state (first-index state matches))
        (set-status state))))

(fn start [state]
  (let [search (search state)]
    (set search.active? true)
    (set search.query "")
    (set search.matches [])
    (set search.index 0)
    (set-status state)))

(fn finish [state]
  (set (. state.search :active?) false)
  (set-status state))

(fn clear [state]
  (let [search (search state)]
    (set search.active? false)
    (set search.query "")
    (set search.matches [])
    (set search.index 0)
    (set state.notice nil)))

(fn backspace [state]
  (let [search (search state)
        len (length search.query)]
    (when (> len 0)
      (set search.query (search.query:sub 1 (- len 1))))
    (rebuild state)))

(fn printable? [key]
  (and (= (type key) "string") (= (length key) 1)
       (let [byte (string.byte key)]
         (and byte (>= byte 32) (not (= byte 127))))))

(fn append-char [state key]
  (set (. state.search :query) (.. state.search.query key))
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
    (jump-to state (+ search.index 1))))

(fn previous [state]
  (let [search (search state)]
    (jump-to state (- search.index 1))))

(fn highlight [state text]
  (if (has-query? state)
      (tui.highlight-matches text (query state))
      text))

(fn status [state]
  (let [search (search state)]
    (if search.active?
        (let [count (length search.matches)]
          (.. "/" search.query " | " count " match" (if (= count 1) "" "es")
              " | enter finish | esc clear"))
        nil)))

{: active?
 : clear
 : handle-input
 : has-query?
 : highlight
 : new-state
 : next
 : previous
 : query
 : start
 : status}
