(local entry-view (require :app.entry))
(local preview (require :preview.core))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
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

(fn selected-entry [state]
  (. state.entries state.selected))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn reviewed-count [entries]
  (accumulate [count 0 _ entry (ipairs entries)]
    (if entry.reviewed (+ count 1) count)))

(fn plural-s [n]
  (if (= n 1) "" "s"))

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
        items [(.. reviewed "/" count " reviewed")
               (.. count " file" (plural-s count))]]
    (when stats
      (table.insert items
                    (.. (tui.color state.theme :status-added
                                   (.. "+" stats.additions))
                        " "
                        (tui.color state.theme :status-deleted
                                   (.. "-" stats.deletions)))))
    (table.concat items separator)))

(fn row-prefix [state selected?]
  (if selected? (tui.color state.theme :selected-marker "> ") "  "))

(fn row-text [state entry selected?]
  (.. (row-prefix state selected?) (reviewed-text state entry) " "
      (status-text state entry) " "
      (search.highlight state (entry-view.path-text entry))))

(fn row [state entry selected?]
  (tui.row (row-text state entry selected?) selected?))

(fn visible-rows [state visible]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        (first-row last-row) (viewport selected count visible)]
    (fcollect [i first-row last-row]
      (let [entry (. entries i)
            selected? (= i selected)]
        (row state entry selected?)))))

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
        selected-entry (selected-entry state)
        (first-row _last-row) (viewport state.selected count visible)
        _ (preview-warm.import-entry state.preview_warm state.preview_cache
                                     state.revision selected-entry)
        left (tui.list (visible-rows state visible)
                       (list-scroll-info first-row count visible))
        right-lines (preview.visible-lines state selected-entry visible
                                           {:nonblocking? true})
        right (tui.lines right-lines (preview.scroll-info state))
        body (tui.split left right state.split_ratio)]
    (tui.screen (header-line state) body (footer state count))))

{: view}
