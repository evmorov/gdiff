(local line-selection (require :app.line-selection))
(local matcher (require :app.search-match))
(local nav (require :app.search-nav))
(local preview (require :preview.core))
(local search-plan (require :app.search-plan))
(local search-status (require :app.search-status))
(local selection (require :app.selection))
(local str (require :util.string))
(local tui (require :tui.core))

(fn new-state []
  (search-plan.new-state))

(fn query [state]
  (or (and state.search state.search.query) ""))

(fn active? [state]
  (and state.search state.search.active? true))

(fn has-query? [state]
  (> (length (query state)) 0))

(fn set-status [state]
  (set state.notice (search-status.notice state.search)))

(fn cursor-position [state]
  (let [row (selection.cursor-position state)]
    (if (= state.focus :right)
        {: row
         :line (preview.source-index-for-display state
                                                 (or state.preview_cursor 1))}
        {: row})))

(fn jump-cursor [state found]
  (set state.focus :right)
  (when found.side
    (set state.split_side found.side))
  (preview.cursor-jump state (or (preview.display-index-for-source state
                                                                   found.line)
                                 found.line)))

(fn select-row [state row]
  (selection.set-match state (if (= state.view_mode :tree)
                                 {:tree-row row}
                                 {:entry row})))

(fn apply-line-match [state found]
  "A line in the selected file gets the cursor now. A line in another file
selects that file first; the view finishes the jump once its preview is
prepared, because display rows are only known then."
  (if (= found.row (selection.cursor-position state))
      (jump-cursor state found)
      (do
        (select-row state found.row)
        (set state.focus :right)
        (set state.search.pending found))))

(fn apply-file-match [state found]
  (line-selection.stop state)
  (set state.focus :left)
  (selection.set-match state found))

(fn apply-match [state found]
  (if found.line
      (apply-line-match state found)
      (apply-file-match state found)))

(fn wrap-index [index count]
  (if (< index 1) count
      (> index count) 1
      index))

(fn jump-to [state index]
  (let [search state.search
        count (length search.matches)]
    (when (> count 0)
      (let [index (wrap-index index count)]
        (set search.index index)
        (apply-match state (. search.matches index))))
    (set-status state)))

(fn rebuild [state ?preserve-selection?]
  (let [search state.search
        matches (matcher.collect-matches state search.query)
        first (nav.first-at-or-after (cursor-position state) matches)]
    (set search.matches matches)
    (set search.index (if (= 0 (length matches)) 0 first))
    (if (or ?preserve-selection? (= 0 (length matches)))
        (set-status state)
        (jump-to state first))))

(fn start [state]
  (set state.search (search-plan.start))
  (set-status state))

(fn finish [state]
  (set state.search (search-plan.finish state.search))
  (set-status state))

(fn clear [state]
  (set state.search (search-plan.clear))
  (set state.notice nil))

(fn backspace [state]
  (let [search state.search]
    (set search.query (search-plan.backspace-query search.query))
    (rebuild state)))

(fn append-char [state key]
  (let [search state.search]
    (set search.query (search-plan.append-query search.query key)))
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
    _ (if (and (= (type key) :table) key.paste)
          (do
            (append-char state key.paste)
            true)
          (search-plan.printable? key)
          (do
            (append-char state key)
            true)
          true)))

(fn next [state]
  (jump-to state (nav.first-after (cursor-position state) state.search.matches)))

(fn previous [state]
  (jump-to state (nav.last-before (cursor-position state) state.search.matches)))

(fn resolve-pending [state]
  (let [search state.search
        found search.pending]
    (set search.pending nil)
    (when (and found (= found.row (selection.cursor-position state)))
      (jump-cursor state found)
      (set search.index (or (nav.index-of search.matches found) search.index))
      (set-status state))))

(fn sync [state display]
  "Refresh the matches when the prepared preview changed, keeping the cursor
where it is unless a jump into this file is still pending."
  (when (has-query? state)
    (let [search state.search]
      (when (not= search.matches-source display)
        (set search.matches-source display)
        (rebuild state true))
      (when search.pending
        (resolve-pending state)))))

(fn label-query [text query]
  (let [query (str.strip-trailing-slash query)]
    (if (and (string.find query "/" 1 true)
             (= nil (string.find text query 1 true)))
        (or (string.match query "([^/]+)$") query)
        query)))

(fn highlight [state text]
  (if (has-query? state)
      (tui.highlight-matches state.theme text (label-query text (query state)))
      text))

(fn matched-lines [state]
  "Set of cached line indexes of the selected file that match the query, so
views can limit highlighting to matching rows."
  (if (has-query? state)
      (let [row (selection.cursor-position state)]
        (collect [_ found (ipairs state.search.matches)]
          (when (and found.line (= found.row row))
            (values found.line true))))
      {}))

(fn matched-display? [state matched display-index]
  (and (. matched (preview.source-index-for-display state display-index)) true))

(fn status [state]
  (search-status.prompt state.search))

{: active?
 : clear
 : finish
 : handle-input
 : has-query?
 : highlight
 : jump-to
 : label-query
 : matched-display?
 : matched-lines
 : new-state
 : next
 : previous
 : query
 : rebuild
 : start
 : status
 : sync}
