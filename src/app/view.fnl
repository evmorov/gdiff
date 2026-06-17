(local entry-view (require :app.entry))
(local preview (require :preview.core))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
(local selection (require :app.selection))
(local sync (require :git.sync))
(local symbols (require :tui.symbols))
(local tui (require :tui.core))

(fn status-color [entry]
  (case entry.kind
    "A" :status-added
    "M" :status-modified
    "D" :status-deleted
    "R" :status-renamed
    "C" :status-copied
    _ :reset))

(fn status-text [state entry]
  (tui.color state.theme (status-color entry) (.. "[" entry.status "]")))

(fn reviewed-text [state entry]
  (if entry.reviewed
      "[x]"
      (tui.color state.theme :muted "[ ]")))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn reviewed-count [entries]
  (accumulate [count 0 _ entry (ipairs entries)]
    (if entry.reviewed (+ count 1) count)))

(fn percentage [part total]
  (if (<= total 0)
      0
      (math.floor (+ 0.5 (* (/ part total) 100)))))

(fn body-row-count [rows]
  (math.max 1 (- rows 4)))

(fn viewport [selected count visible]
  (let [top (clamp (- selected (math.floor (/ visible 2))) 1
                   (math.max 1 (- count visible -1)))
        bottom (math.min count (+ top visible -1))]
    (values top bottom)))

(fn list-scroll-info [top count visible]
  (when (> count visible)
    {:offset (- top 1) :visible visible :total count}))

(fn header-line [state]
  (let [separator (.. " " (tui.color state.theme :muted symbols.line.separator)
                      " ")
        items [state.revision_label
               "/ search"
               "C-d/C-u preview"
               "r refresh/sync"
               "` tree"
               "y copy"
               "p PR"
               "space check"
               "a all/none"
               "enter/o open"
               "Ctrl-C quit"]]
    (table.concat items separator)))

(fn footer-summary [state count]
  (let [reviewed (reviewed-count state.entries)
        separator (.. " " (tui.color state.theme :muted symbols.line.separator)
                      " ")
        stats state.diff_stats
        reviewed-percent (percentage reviewed count)
        items [(.. reviewed "/" count " files")
               (.. reviewed-percent "% reviewed")]]
    (when stats
      (table.insert items
                    (.. (tui.color state.theme :status-added
                                   (.. "+" stats.additions))
                        " "
                        (tui.color state.theme :status-deleted
                                   (.. "-" stats.deletions)))))
    (table.concat items separator)))

(fn indent [depth]
  (string.rep "  " (or depth 0)))

(fn row-prefix [state selected? depth]
  (.. (if selected? (tui.color state.theme :selected-marker "> ") "  ")
      (indent depth)))

(fn file-label [descriptor]
  (or descriptor.name (entry-view.path-text descriptor.entry)))

(fn file-row-text [state descriptor selected?]
  (let [entry descriptor.entry]
    (.. (row-prefix state selected? descriptor.depth)
        (reviewed-text state entry) " " (status-text state entry) " "
        (search.highlight state (file-label descriptor)))))

(fn folder-row-text [state descriptor selected?]
  (.. (row-prefix state selected? descriptor.depth)
      (tui.color state.theme :folder (search.highlight state descriptor.name))))

(fn selected-row? [state descriptor row-index]
  (selection.selected-row? state descriptor row-index))

(fn display-row [state descriptor row-index]
  (if (= descriptor.type :folder)
      (let [selected? (selected-row? state descriptor row-index)]
        (tui.row (folder-row-text state descriptor selected?) selected?))
      (let [selected? (selected-row? state descriptor row-index)]
        (tui.row (file-row-text state descriptor selected?) selected?))))

(fn display-rows [state]
  (selection.rows state))

(fn display-selected-row [state rows]
  (selection.selected-row-index state rows))

(fn visible-rows [state rows first-row last-row]
  (fcollect [i first-row last-row]
    (display-row state (. rows i) i)))

(fn body-left [state visible]
  (let [rows (display-rows state)
        count (length rows)
        selected (display-selected-row state rows)
        (first-row last-row) (viewport selected count visible)]
    (tui.list (visible-rows state rows first-row last-row)
              (list-scroll-info first-row count visible))))

(fn footer [state count]
  (let [prompt (search.status state)
        warning (sync.warning state.sync)
        summary (footer-summary state count)]
    (if prompt (tui.footer :prompt prompt summary) warning
        (tui.footer :warning warning summary)
        (tui.footer :notice state.notice summary))))

(fn view [state rows _cols]
  (let [count (length state.entries)
        visible (body-row-count rows)
        selected-entry (selection.selected-entry state)
        _ (preview-warm.import-entry state.preview_warm state.preview_cache
                                     state.revision selected-entry)
        left (body-left state visible)
        right-lines (if (and (= state.view_mode :tree) (not selected-entry))
                        (do
                          (set state.preview_scroll 0)
                          (set state.preview_total 0)
                          [])
                        (preview.visible-lines state selected-entry visible
                                               {:nonblocking? true}))
        right (tui.lines right-lines (preview.scroll-info state))
        body (tui.split left right state.split_ratio)]
    (tui.screen (header-line state) body (footer state count))))

{: view}
