(local entry-view (require :app.entry))
(local preview (require :preview.core))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
(local sync (require :git.sync))
(local tui (require :tui.core))

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
  (let [reviewed (reviewed-count state.entries)
        help (table.concat [" | / search"
                            " | C-d/C-u preview"
                            " | r refresh"
                            " | y copy"
                            " | space check"
                            " | a all/none"
                            " | enter/o open"
                            " | Ctrl-C quit"])]
    (.. "gdiff " state.revision_label " | " count " file" (plural-s count)
        " | " reviewed "/" count " reviewed" help)))

(fn row-prefix [selected?]
  (if selected? "> " "  "))

(fn row-text [state entry selected?]
  (.. (row-prefix selected?) (reviewed-text entry) " " (status-text entry) " "
      (search.highlight state (entry-view.path-text entry))))

(fn row [state entry selected?]
  (tui.row (row-text state entry selected?) selected?))

(fn visible-rows [state rows]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        (first-row last-row) (viewport selected count rows)]
    (fcollect [i first-row last-row]
      (let [entry (. entries i)
            selected? (= i selected)]
        (row state entry selected?)))))

(fn footer [state]
  (let [prompt (search.status state)
        warning (sync.warning state.sync)]
    (if prompt (tui.footer :prompt prompt)
        warning (tui.footer :warning warning)
        (tui.footer :notice state.notice))))

(fn view [state rows _cols]
  (preview-warm.update state.preview_warm state.preview_cache)
  (let [count (length state.entries)
        left (tui.list (visible-rows state rows))
        right (tui.lines (preview.visible-lines state (selected-entry state)
                                                rows))
        body (tui.split left right state.split_ratio)]
    (tui.screen (header-line state count) body (footer state))))

{: view}
