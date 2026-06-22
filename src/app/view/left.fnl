(local entry-view (require :app.entry))
(local search (require :app.search))
(local selection (require :app.selection))
(local tui (require :tui.core))
(local math-util (require :util.math))

(fn viewport [selected count visible]
  (let [top (math-util.clamp (- selected (math.floor (/ visible 2))) 1
                             (math.max 1 (- count visible -1)))
        bottom (math.min count (+ top visible -1))]
    (values top bottom)))

(fn scroll-info [top count visible]
  (when (> count visible)
    {:offset (- top 1) : visible :total count}))

(fn status-color [entry]
  (case entry.kind
    "A" :status-added
    "M" :status-modified
    "D" :status-deleted
    "R" :status-renamed
    "C" :status-copied
    _ :reset))

(fn status-text [state entry]
  (if entry.unstaged?
      (tui.color state.theme :status-untracked "[?]")
      (tui.color state.theme (status-color entry) (.. "[" entry.status "]"))))

(fn reviewed-text [state entry]
  (if entry.reviewed
      (.. (tui.color state.theme :muted "[") "x"
          (tui.color state.theme :muted "]"))
      (tui.color state.theme :muted "[ ]")))

(fn indent [depth]
  (string.rep "  " (or depth 0)))

(fn row-prefix [state selected? depth]
  (.. (if selected? (tui.color state.theme :selected-marker "> ") "  ")
      (indent depth)))

(fn file-label [descriptor]
  (or descriptor.name (entry-view.path-text descriptor.entry)))

(fn file-row-text [state descriptor selected?]
  (if descriptor.unchanged
      (.. (row-prefix state selected? descriptor.depth)
          (search.highlight state (file-label descriptor)))
      (let [entry descriptor.entry]
        (.. (row-prefix state selected? descriptor.depth)
            (reviewed-text state entry) " " (status-text state entry) " "
            (search.highlight state (file-label descriptor))))))

(fn folder-row-text [state descriptor selected?]
  (.. (row-prefix state selected? descriptor.depth)
      (search.highlight state descriptor.name)
      (if descriptor.expanded
          (.. " " (tui.color state.theme :faint "(expanded)"))
          "")))

(fn display-row [state descriptor row-index]
  (let [selected? (selection.selected-row? state descriptor row-index)]
    (if (= descriptor.type :folder)
        (tui.row (folder-row-text state descriptor selected?) selected?)
        (tui.row (file-row-text state descriptor selected?) selected?))))

(fn visible-rows [state rows first-row last-row]
  (fcollect [i first-row last-row]
    (display-row state (. rows i) i)))

(fn body [state visible]
  (let [rows (selection.rows state)
        count (length rows)
        selected (selection.selected-row-index state rows)
        (first-row last-row) (viewport selected count visible)
        visible-rows (visible-rows state rows first-row last-row)
        scroll (scroll-info first-row count visible)]
    (set state.files_x_scroll 0)
    (set state.files_x_max_scroll 0)
    (tui.list visible-rows scroll 0 0)))

{: body}
