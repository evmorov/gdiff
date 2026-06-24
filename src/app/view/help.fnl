(local tui (require :tui.core))

(local gap 3)

(local groups [{:title "Common"
                :items [["↑ / k" "Move up"]
                        ["↓ / j" "Move down"]
                        ["gg" "Jump to top"]
                        ["G" "Jump to bottom"]
                        ["tab" "Switch focus: files / preview"]
                        ["[ / ]" "Resize split"]
                        ["/" "Search"]
                        ["n / N" "Next / previous match"]
                        ["q" "Clear search / exit selection"]
                        ["r" "Refresh and sync"]
                        ["p" "Open pull request"]
                        ["?" "Toggle this help"]
                        ["Ctrl-C" "Quit"]]}
               {:title "Files"
                :items [["enter / o" "Open file or folder"]
                        ["y" "Copy relative path"]
                        ["Y" "Copy full path"]
                        ["space" "Toggle reviewed"]
                        ["a" "Toggle all reviewed"]
                        ["`" "Toggle file tree"]
                        ["e" "Expand / collapse folder"]
                        ["E" "Expand / collapse all nested"]]}
               {:title "Preview"
                :items [["← / h" "Scroll preview left"]
                        ["→ / l" "Scroll preview right"]
                        ["C-d / C-u" "Page preview down / up"]
                        ["w" "Toggle wrap"]
                        ["f" "Toggle full file context"]
                        ["v" "Select lines in diff (toggle)"]
                        ["y" "Yank line or selection"]
                        ["Y" "Yank with path, fenced"]]}])

(fn pad [text width]
  (let [missing (- width (tui.visible-length text))]
    (if (< 0 missing) (.. text (string.rep " " missing)) text)))

(fn group-key-width [group]
  (accumulate [width 0 _ [keys] (ipairs group.items)]
    (math.max width (tui.visible-length keys))))

;; Render a group to a block of lines: a heading followed by padded key rows.
(fn render-group [state group]
  (let [key-width (group-key-width group)]
    (icollect [_ [keys label] (ipairs group.items)
               &into [(tui.color state.theme :search-match group.title)]]
      (.. (tui.color state.theme :selected-marker (pad keys key-width)) "  "
          label))))

(fn block-total [blocks]
  (+ (accumulate [sum 0 _ block (ipairs blocks)] (+ sum (length block)))
     (math.max 0 (- (length blocks) 1))))

;; Pack blocks into `columns` columns in order, balancing height by moving on
;; once a column reaches the per-column target. A blank line joins blocks.
(fn distribute [blocks columns]
  (let [cols (fcollect [_ 1 columns] [])
        target (math.max 1 (math.ceil (/ (block-total blocks) columns)))]
    (var col 1)
    (var height 0)
    (each [_ block (ipairs blocks)]
      (when (and (< 0 height) (< col columns)
                 (< target (+ height 1 (length block))))
        (set col (+ col 1))
        (set height 0))
      (table.insert (. cols col) block)
      (set height (+ height (if (< 0 height) 1 0) (length block))))
    cols))

(fn flatten-column [blocks]
  (let [lines []]
    (each [index block (ipairs blocks)]
      (when (< 1 index) (table.insert lines ""))
      (each [_ line (ipairs block)] (table.insert lines line)))
    lines))

(fn column [blocks]
  (let [lines (flatten-column blocks)]
    {: lines
     :width (accumulate [width 0 _ line (ipairs lines)]
              (math.max width (tui.visible-length line)))}))

(fn layout-width [columns]
  (+ (accumulate [width 0 _ col (ipairs columns)] (+ width col.width))
     (* gap (math.max 0 (- (length columns) 1)))))

;; Most columns that fit the terminal width, preferring one column per group.
(fn choose-columns [blocks term-cols]
  (var chosen 1)
  (var done false)
  (for [n (length blocks) 2 -1]
    (when (not done)
      (let [columns (icollect [_ bs (ipairs (distribute blocks n))]
                      (column bs))]
        (when (<= (layout-width columns) term-cols)
          (set chosen n)
          (set done true)))))
  chosen)

(fn join-columns [columns]
  (let [height (accumulate [h 0 _ col (ipairs columns)]
                 (math.max h (length col.lines)))
        sep (string.rep " " gap)
        last (length columns)]
    (fcollect [row 1 height]
      (table.concat (icollect [index col (ipairs columns)]
                      (let [line (or (. col.lines row) "")]
                        (if (= index last) line (pad line col.width))))
                    sep))))

(fn lines [state]
  (let [blocks (icollect [_ group (ipairs groups)] (render-group state group))
        columns (icollect [_ bs (ipairs (distribute blocks
                                                    (choose-columns blocks
                                                                    (or state.term_cols
                                                                        80))))]
                  (column bs))]
    (join-columns columns)))

(fn modal [state]
  (tui.modal "Keyboard shortcuts" (lines state)))

{: choose-columns
 : distribute
 : groups
 : join-columns
 : lines
 : modal
 : render-group}
