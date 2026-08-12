(local entry-view (require :app.entry))
(local search (require :app.search))
(local selection (require :app.selection))
(local tui (require :tui.core))
(local math-util (require :util.math))
(local scroll-util (require :util.scroll))

(fn viewport [selected count visible]
  (let [top (math-util.clamp (- selected (math.floor (/ visible 2))) 1
                             (math.max 1 (- count visible -1)))
        bottom (math.min count (+ top visible -1))]
    (values top bottom)))

(fn scroll-info [top count visible]
  (scroll-util.info (- top 1) count visible))

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

(fn move-note-text [state entry]
  (let [note (entry-view.move-note entry)]
    (if (= note "")
        ""
        (tui.color state.theme :status-renamed note))))

(fn file-row-text [state descriptor selected?]
  (if descriptor.unchanged
      (.. (row-prefix state selected? descriptor.depth)
          (search.highlight state (file-label descriptor)))
      (let [entry descriptor.entry]
        (.. (row-prefix state selected? descriptor.depth)
            (reviewed-text state entry) " " (status-text state entry) " "
            (search.highlight state (file-label descriptor))
            (move-note-text state entry)))))

(fn folder-row-text [state descriptor selected?]
  (.. (row-prefix state selected? descriptor.depth)
      (search.highlight state descriptor.name)
      (if descriptor.expanded
          (.. " " (tui.color state.theme :faint "(expanded)"))
          "")))

(fn row-text [state descriptor selected?]
  (if (= descriptor.type :folder)
      (folder-row-text state descriptor selected?)
      (file-row-text state descriptor selected?)))

(fn content-width [state]
  (accumulate [width 0 _ descriptor (ipairs (selection.rows state))]
    (math.max width (tui.visible-length (row-text state descriptor false)))))

(fn display-row [state descriptor row-index]
  (let [selected? (selection.selected-row? state descriptor row-index)
        focused-selection? (and selected? (= state.focus :left))]
    (tui.row (row-text state descriptor selected?) focused-selection?)))

(fn visible-rows [state rows first-row last-row]
  (fcollect [i first-row last-row]
    (display-row state (. rows i) i)))

(fn prepare [state]
  (set state.files_x_scroll 0)
  (set state.files_x_max_scroll 0))

(fn body [state visible]
  (let [rows (selection.rows state)
        count (length rows)
        selected (selection.selected-row-index state rows)
        (first-row last-row) (viewport selected count visible)
        visible-rows (visible-rows state rows first-row last-row)
        scroll (scroll-info first-row count visible)]
    (tui.list visible-rows scroll 0 0)))

{: body : content-width : prepare}
