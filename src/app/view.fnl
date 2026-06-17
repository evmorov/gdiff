(local entry-view (require :app.entry))
(local preview (require :preview.core))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
(local selection (require :app.selection))
(local sync (require :git.sync))
(local ansi (require :tui.ansi))
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
      (.. (tui.color state.theme :muted "[") "x"
          (tui.color state.theme :muted "]"))
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
               "w wrap"
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
      (search.highlight state descriptor.name)))

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
        (first-row last-row) (viewport selected count visible)
        visible-rows (visible-rows state rows first-row last-row)
        scroll (list-scroll-info first-row count visible)]
    (set state.files_x_scroll 0)
    (set state.files_x_max_scroll 0)
    (tui.list visible-rows scroll 0 0)))

(fn footer [state count]
  (let [prompt (search.status state)
        warning (sync.warning state.sync)
        summary (footer-summary state count)]
    (if prompt (tui.footer :prompt prompt summary) warning
        (tui.footer :warning warning summary)
        (tui.footer :notice state.notice summary))))

(fn preview-content-width [state cols]
  (let [(_left-cols right-cols) (tui.components.split.widths cols
                                                             state.split_ratio)
        scroll? (preview.scroll-info state)]
    (math.max 0 (if scroll? (- right-cols 1) right-cols))))

(fn preview-horizontal-lines [state selected-entry]
  (if (and (= state.view_mode :tree) (not selected-entry))
      []
      (preview.nonblocking-lines state selected-entry)))

(fn wrap-line [line width]
  (let [width (math.max 1 width)
        line-width (tui.visible-length line)
        continued-width (math.max 1 (- width 1))]
    (if (<= line-width width)
        [line]
        (let [out []]
          (var offset 0)
          (while (< offset line-width)
            (let [remaining (- line-width offset)
                  continued? (> remaining width)
                  chunk-width (if continued? continued-width width)
                  chunk (ansi.window line offset chunk-width)]
              (table.insert out (if continued?
                                    (.. chunk symbols.line.wrap-arrow)
                                    chunk))
              (set offset (+ offset chunk-width))))
          out))))

(fn wrap-lines [lines width]
  (let [out []]
    (each [_ line (ipairs lines)]
      (each [_ part (ipairs (wrap-line line width))]
        (table.insert out part)))
    out))

(fn preview-display-lines [state lines width]
  (if state.preview_wrap?
      (wrap-lines lines width)
      lines))

(fn preview-scroll? [lines visible]
  (> (length lines) visible))

(fn right-content-width [cols state scroll?]
  (let [(_left-cols right-cols) (tui.components.split.widths cols
                                                             state.split_ratio)]
    (math.max 0 (if scroll? (- right-cols 1) right-cols))))

(fn preview-lines-for-width [state lines visible cols]
  (let [wide-width (right-content-width cols state false)
        wide-lines (preview-display-lines state lines wide-width)
        scroll? (preview-scroll? wide-lines visible)
        width (right-content-width cols state scroll?)]
    (if (and state.preview_wrap? scroll? (not (= width wide-width)))
        (preview-display-lines state lines width)
        wide-lines)))

(fn set-preview-scroll [state lines visible]
  (set state.preview_rows visible)
  (set state.preview_total (length lines))
  (let [max-scroll (math.max 0 (- (length lines) visible))]
    (set state.preview_scroll (clamp (or state.preview_scroll 0) 0 max-scroll))))

(fn visible-preview-lines [state lines visible]
  (let [first (+ (or state.preview_scroll 0) 1)
        last (math.min (length lines) (+ (or state.preview_scroll 0) visible))]
    (if (> first last)
        []
        (fcollect [i first last]
          (. lines i)))))

(fn view [state rows cols]
  (let [count (length state.entries)
        visible (body-row-count rows)
        selected-entry (selection.selected-entry state)
        _ (preview-warm.import-entry state.preview_warm state.preview_cache
                                     state.revision selected-entry)
        left (body-left state visible)
        right-all-lines (preview-horizontal-lines state selected-entry)
        right-display-lines (if (and (= state.view_mode :tree)
                                     (not selected-entry))
                                []
                                (preview-lines-for-width state right-all-lines
                                                         visible cols))
        _ (set-preview-scroll state right-display-lines visible)
        right-lines (visible-preview-lines state right-display-lines visible)
        _ (if state.preview_wrap?
              (preview.set-horizontal-scroll-limit state [] 0)
              (preview.set-horizontal-scroll-limit state right-all-lines
                                                   (preview-content-width state
                                                                          cols)))
        right (tui.lines right-lines (preview.scroll-info state)
                         state.preview_x_scroll state.preview_x_max_scroll)
        body (tui.split left right state.split_ratio)]
    (tui.screen (header-line state) body (footer state count))))

{: view}
