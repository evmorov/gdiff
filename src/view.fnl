(local entry-view (require :entry))
(local preview (require :preview))
(local preview-warm (require :preview_warm))
(local search (require :search))
(local sync (require :sync))
(local tui (require :tui))

(fn status-color [entry]
  (case entry.kind
    "A" :added
    "M" :modified
    "D" :deleted
    "R" :renamed
    "C" :copied
    _ :reset))

(fn status-text [entry]
  (tui.color (status-color entry) (.. "[" entry.status "]")))

(fn reviewed-text [entry]
  (if entry.reviewed
      (tui.color :added "[x]")
      (tui.color :dim "[ ]")))

(fn selected-entry [state]
  (. state.entries state.selected))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn reviewed-count [entries]
  (accumulate [count 0 _ entry (ipairs entries)]
    (if entry.reviewed (+ count 1) count)))

(fn plural-s [n]
  (if (= n 1) "" "s"))

(fn viewport [selected count rows]
  (let [usable (math.max 1 (- rows 3))
        top (clamp (- selected (math.floor (/ usable 2))) 1
                   (math.max 1 (- count usable -1)))
        bottom (math.min count (+ top usable -1))]
    (values top bottom)))

(fn header-line [state count]
  (let [reviewed (reviewed-count state.entries)]
    (.. "gdiff " state.revision_label " | " count " file" (plural-s count)
        " | " reviewed "/" count " reviewed"
        " | / search | C-d/C-u preview | r refresh | y copy | space check | a all/none | enter/o open | Ctrl-C quit")))

(fn row-prefix [selected?]
  (if selected? "> " "  "))

(fn row-text [state entry selected?]
  (.. (row-prefix selected?) (reviewed-text entry) " " (status-text entry) " "
      (search.highlight state (entry-view.path-text entry))))

(fn visible-rows [state rows]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        (first-row last-row) (viewport selected count rows)]
    (fcollect [i first-row last-row]
      (let [entry (. entries i)
            selected? (= i selected)]
        {:text (row-text state entry selected?) :selected? selected?}))))

(fn view [state rows _cols]
  (preview-warm.update state.preview_warm state.preview_cache)
  (let [count (length state.entries)]
    {:header (header-line state count)
     :rows (visible-rows state rows)
     :preview (preview.visible-lines state (selected-entry state) rows)
     :split_ratio state.split_ratio
     :prompt (search.status state)
     :warning (sync.warning state.sync)
     :notice state.notice}))

{: view}
