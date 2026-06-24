(local chrome (require :app.view.chrome))
(local help-view (require :app.view.help))
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
        _ (left-view.prepare state)
        _ (preview-view.prepare state visible cols selected)
        left (left-view.body state visible)
        right (preview-view.body state visible)
        body (tui.split left right state.split_ratio)
        overlay (when state.show_help? (help-view.modal state))]
    (tui.screen (chrome.header state) body (chrome.footer state count) overlay)))

{: view}
