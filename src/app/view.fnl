(local chrome (require :app.view.chrome))
(local help-view (require :app.view.help))
(local left-view (require :app.view.left))
(local preview-view (require :app.view.preview))
(local preview-split-view (require :app.view.preview-split))
(local preview (require :preview.core))
(local selection (require :app.selection))
(local tui (require :tui.core))

(fn body-row-count [rows]
  (math.max 1 (- rows 4)))

(fn right-pane [state visible cols selected]
  (if (preview.split? state selected.entry)
      (do
        (preview-split-view.prepare state visible cols selected)
        (preview-split-view.body state visible cols))
      (do
        (set state.split_rows nil)
        (preview-view.prepare state visible cols selected)
        (preview-view.body state visible))))

(fn view [state rows cols]
  (let [count (length state.entries)
        visible (body-row-count rows)
        selected (selection.selected-context state)
        _ (preview.prepare-entry state selected.entry)
        _ (left-view.prepare state)
        left (left-view.body state visible)
        right (right-pane state visible cols selected)
        body (tui.split left right state.split_ratio)
        overlay (when state.show_help? (help-view.modal state))]
    (tui.screen (chrome.header state count) body (chrome.footer state) overlay)))

{: view}
