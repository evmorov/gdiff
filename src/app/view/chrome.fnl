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

(fn delta [state added deleted]
  (.. (tui.color state.theme :status-added (.. "+" added)) " "
      (tui.color state.theme :status-deleted (.. "-" deleted))))

(fn summary [state count]
  (let [reviewed (review.count state.entries)
        stats state.diff_stats
        reviewed-percent (percentage reviewed count)
        items [(.. reviewed "/" count " files")
               (.. reviewed-percent "% reviewed")]]
    (when stats
      (table.insert items
                    (.. "all " (delta state stats.additions stats.deletions)))
      (when stats.code_additions
        (table.insert items
                      (.. "code "
                          (delta state stats.code_additions
                                 stats.code_deletions))))
      (when stats.comment_additions
        (table.insert items
                      (.. "comments "
                          (delta state stats.comment_additions
                                 stats.comment_deletions))))
      (when stats.no_tests_additions
        (table.insert items
                      (.. "no tests "
                          (delta state stats.no_tests_additions
                                 stats.no_tests_deletions)))))
    (table.concat items (separator state))))

(fn header [state count]
  (let [items [state.revision_label "? help" "Ctrl-C quit"]]
    {:text (table.concat items (separator state)) :right (summary state count)}))

(fn toggle-label [label on?]
  (.. label " " (if on? "on" "off")))

(fn highlighted-toggle [state label on? ?role]
  (let [text (toggle-label label on?)]
    (if on? (tui.color state.theme (or ?role :status-added) text) text)))

(fn status-widgets [state]
  (table.concat [(highlighted-toggle state :tree (= state.view_mode :tree))
                 (highlighted-toggle state :wrap state.preview_wrap?)
                 (highlighted-toggle state :num state.show_numbers?)
                 (highlighted-toggle state :blame state.show_blame?)
                 (highlighted-toggle state :split state.split_mode?)
                 (highlighted-toggle state :context state.full_context?)
                 (highlighted-toggle state :hide-reviewed state.hide_reviewed?
                                     :status-modified)
                 (highlighted-toggle state :no-comments state.hide_comments?
                                     :status-modified)]
                (separator state)))

(fn footer [state]
  (let [prompt (search.status state)
        warning (sync.warning state.sync)
        status (status-widgets state)]
    (if prompt (tui.footer :prompt prompt status) warning
        (tui.footer :warning warning status)
        (tui.footer :notice state.notice status))))

{: footer : header}
