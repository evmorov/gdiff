(local entry-view (require :app.entry))
(local preview (require :preview.core))
(local tree (require :app.tree))
(local tui (require :tui.core))

(local separator " │ ")

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

(fn tree-label [row]
  (if (= row.type :folder)
      row.name
      (or row.name (entry-view.path-text row.entry))))

(fn tree-match [query row-index row]
  (if (contains? (tree-label row) query)
      {:tree-row row-index :entry row.entry-index}))

(fn collect-matches [state query]
  (let [matches []]
    (when (> (length query) 0)
      (if (= state.view_mode :tree)
          (each [row-index row (ipairs (tree.rows state.entries))]
            (let [found (tree-match query row-index row)]
              (when found
                (table.insert matches found))))
          (each [entry-index entry (ipairs state.entries)]
            (let [found (path-match query entry-index entry)]
              (when found
                (table.insert matches found))))))
    matches))

(fn cursor-position [state]
  (if (= state.view_mode :tree)
      (or state.tree_selected_row 1)
      state.selected))

(fn match-position [found]
  (or found.tree-row found.entry))

(fn set-status [state]
  (let [search (search state)
        count (length search.matches)]
    (set state.notice
         (if search.active?
             (.. "/" search.query separator count " match"
                 (if (= count 1) "" "es") separator "enter finish" separator
                 "esc clear")
             (and (> (length search.query) 0)
                  (if (= count 0)
                      (.. "No matches for '" search.query "'")
                      (.. "Search: " search.index "/" count " " search.query
                          separator "n/N next/prev" separator "q clear")))))))

(fn first-index [state matches]
  (let [cursor (cursor-position state)]
    (var index 1)
    (var found? false)
    (each [i found (ipairs matches)]
      (when (and (not found?) (>= (match-position found) cursor))
        (set index i)
        (set found? true)))
    index))

(fn set-tree-match [state found]
  (set state.tree_selected_row found.tree-row)
  (when found.entry
    (set state.selected found.entry)))

(fn apply-match [state found]
  (when found
    (if found.tree-row
        (set-tree-match state found)
        (set state.selected found.entry))
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

(fn next-index-from-selection [state matches]
  (let [cursor (cursor-position state)]
    (var index 1)
    (var found? false)
    (each [i found (ipairs matches)]
      (when (and (not found?) (> (match-position found) cursor))
        (set index i)
        (set found? true)))
    index))

(fn previous-index-from-selection [state matches]
  (let [count (length matches)
        cursor (cursor-position state)]
    (var index count)
    (var found? false)
    (for [i count 1 -1]
      (let [found (. matches i)]
        (when (and found (not found?) (< (match-position found) cursor))
          (set index i)
          (set found? true))))
    index))

(fn rebuild [state ?preserve-selection?]
  (let [search (search state)
        matches (collect-matches state search.query)]
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
    (jump-to state (next-index-from-selection state search.matches))))

(fn previous [state]
  (let [search (search state)]
    (jump-to state (previous-index-from-selection state search.matches))))

(fn highlight [state text]
  (if (has-query? state)
      (tui.highlight-matches state.theme text (query state))
      text))

(fn status [state]
  (let [search (search state)]
    (if search.active?
        (let [count (length search.matches)]
          (.. "/" search.query separator count " match"
              (if (= count 1) "" "es") separator "enter finish" separator
              "esc clear"))
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
 : rebuild
 : start
 : status}
