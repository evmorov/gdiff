(local chrome (require :app.view.chrome))
(local help-view (require :app.view.help))
(local left-view (require :app.view.left))
(local preview-view (require :app.view.preview))
(local preview-split-view (require :app.view.preview-split))
(local preview (require :preview.core))
(local selection (require :app.selection))
(local tui (require :tui.core))

(local left-gap 2)
(local min-split-ratio 0.1)
(local max-split-ratio 0.4)

(fn body-row-count [rows]
  (math.max 1 (- rows 4)))

(fn auto-split-ratio [state cols]
  (let [desired (+ (left-view.content-width state) left-gap)
        ratio (/ desired (math.max 1 (- cols 1)))]
    (math.max min-split-ratio (math.min max-split-ratio ratio))))

(fn ensure-split-ratio [state cols]
  (when (and state.split_ratio_auto? cols (> cols 0))
    (set state.split_ratio (auto-split-ratio state cols))
    (set state.split_ratio_auto? false)))

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
  (ensure-split-ratio state cols)
  (let [count (length state.entries)
        visible (body-row-count rows)
        selected (selection.selected-context state)
        _ (preview.prepare-entry state selected.entry)
        _ (left-view.prepare state)
        left (left-view.body state visible)
        right (right-pane state visible cols selected)
        body (tui.split left right state.split_ratio)
        overlay (when state.show_help? (help-view.modal state))]
    (tui.screen (chrome.header state) body (chrome.footer state count) overlay)))

{: view}
