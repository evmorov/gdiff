(local preview (require :preview.core))
(local selection (require :app.selection))
(local tui (require :tui.core))
(local wrap (require :tui.wrap))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn content-width [state cols scroll?]
  (let [(_left-cols right-cols) (tui.components.split.widths cols
                                                             state.split_ratio)]
    (math.max 0 (if scroll? (- right-cols 1) right-cols))))

(fn raw-lines [state selected-entry]
  (if (and (= state.view_mode :tree) (not selected-entry))
      []
      (preview.nonblocking-lines state selected-entry)))

(fn display-lines [state lines width]
  (if state.preview_wrap?
      (wrap.lines lines width)
      lines))

(fn scroll? [lines visible]
  (> (length lines) visible))

(fn lines-for-width [state lines visible cols]
  (let [wide-width (content-width state cols false)
        wide-lines (display-lines state lines wide-width)
        scroll? (scroll? wide-lines visible)
        width (content-width state cols scroll?)]
    (if (and state.preview_wrap? scroll? (not (= width wide-width)))
        (display-lines state lines width)
        wide-lines)))

(fn set-scroll [state lines visible]
  (set state.preview_rows visible)
  (set state.preview_total (length lines))
  (let [max-scroll (math.max 0 (- (length lines) visible))]
    (set state.preview_scroll (clamp (or state.preview_scroll 0) 0 max-scroll))))

(fn visible-lines [state lines visible]
  (let [first (+ (or state.preview_scroll 0) 1)
        last (math.min (length lines) (+ (or state.preview_scroll 0) visible))]
    (if (> first last)
        []
        (fcollect [i first last]
          (. lines i)))))

(fn has-vertical-scroll? [state]
  (not (= nil (preview.scroll-info state))))

(fn update-horizontal-scroll [state raw-lines cols]
  (if state.preview_wrap?
      (preview.set-horizontal-scroll-limit state [] 0)
      (preview.set-horizontal-scroll-limit state raw-lines
                                           (content-width state cols
                                                          (has-vertical-scroll? state)))))

(fn body [state visible cols]
  (let [selected-entry (selection.selected-entry state)
        raw (raw-lines state selected-entry)
        display (if (and (= state.view_mode :tree) (not selected-entry))
                    []
                    (lines-for-width state raw visible cols))
        _ (set-scroll state display visible)
        visible-lines (visible-lines state display visible)
        _ (update-horizontal-scroll state raw cols)]
    (tui.lines visible-lines (preview.scroll-info state) state.preview_x_scroll
               state.preview_x_max_scroll)))

{: body
 : content-width
 : display-lines
 : lines-for-width
 : raw-lines
 : has-vertical-scroll?
 : scroll?
 : set-scroll
 : update-horizontal-scroll
 : visible-lines}
