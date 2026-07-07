(local review (require :app.review))
(local search (require :app.pane-search))
(local sync (require :git.sync))
(local symbols (require :tui.symbols))
(local tui (require :tui.core))

(fn percentage [part total]
  (if (<= total 0)
      0
      (math.floor (+ 0.5 (* (/ part total) 100)))))

(fn separator [state]
  (.. " " (tui.color state.theme :muted symbols.line.separator) " "))

(fn summary [state count]
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

(fn header [state count]
  (let [items [state.revision_label "? help" "Ctrl-C quit"]]
    {:text (table.concat items (separator state)) :right (summary state count)}))

(fn toggle-label [label on?]
  (.. label " " (if on? "on" "off")))

(fn status-widgets [state]
  (let [hide (toggle-label :hide state.hide_reviewed?)]
    (table.concat [(toggle-label :wrap state.preview_wrap?)
                   (toggle-label :num state.show_numbers?)
                   (toggle-label :blame state.show_blame?)
                   (toggle-label :split state.split_mode?)
                   (toggle-label :context state.full_context?)
                   (if state.hide_reviewed?
                       (tui.color state.theme :status-added hide)
                       hide)] (separator state))))

(fn footer [state]
  (let [prompt (search.status state)
        warning (sync.warning state.sync)
        status (status-widgets state)]
    (if prompt (tui.footer :prompt prompt status) warning
        (tui.footer :warning warning status)
        (tui.footer :notice state.notice status))))

{: footer : header}
