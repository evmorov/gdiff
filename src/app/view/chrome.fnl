(local review (require :app.review))
(local search (require :app.search))
(local sync (require :git.sync))
(local symbols (require :tui.symbols))
(local tui (require :tui.core))

(fn percentage [part total]
  (if (<= total 0)
      0
      (math.floor (+ 0.5 (* (/ part total) 100)))))

(fn separator [state]
  (.. " " (tui.color state.theme :muted symbols.line.separator) " "))

(fn header [state]
  (let [items [state.revision_label "? help" "Ctrl-C quit"]]
    (table.concat items (separator state))))

(fn footer-summary [state count]
  (let [reviewed (review.count state.entries)
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
    (table.concat items (separator state))))

(fn footer [state count]
  (let [prompt (search.status state)
        warning (sync.warning state.sync)
        summary (footer-summary state count)]
    (if prompt (tui.footer :prompt prompt summary) warning
        (tui.footer :warning warning summary)
        (tui.footer :notice state.notice summary))))

{: footer : header}
