(local chrome (require :app.view.chrome))
(local left-view (require :app.view.left))
(local preview-view (require :app.view.preview))
(local preview (require :preview.core))
(local selection (require :app.selection))
(local tui (require :tui.core))

(fn body-row-count [rows]
  (math.max 1 (- rows 4)))

(fn view [state rows cols]
  (let [count (length state.entries)
        visible (body-row-count rows)
        selected (selection.selected-context state)
        _ (preview.prepare-entry state selected.entry)
        left (left-view.body state visible)
        right (preview-view.body state visible cols selected)
        body (tui.split left right state.split_ratio)]
    (tui.screen (chrome.header state) body (chrome.footer state count))))

{: view}
