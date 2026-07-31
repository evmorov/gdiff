(local math-util (require :util.math))
(local preview (require :preview.core))
(local scroll-util (require :util.scroll))

(fn line-ref [refs ?source-map index]
  (let [source (if ?source-map (. ?source-map index) index)
        ref (and source (. refs source))]
    (when ref ref)))

(fn scan-refs [refs ?source-map from to step]
  (var at nil)
  (for [i from to step &until at]
    (when (line-ref refs ?source-map i)
      (set at i)))
  at)

(fn nearest-line-ref [refs ?source-map total start]
  (let [at (or (scan-refs refs ?source-map start total 1)
               (scan-refs refs ?source-map (- start 1) 1 -1))]
    (when at
      (values (line-ref refs ?source-map at) at))))

(fn row-ref [row]
  (if row.new-no {:side :new :no row.new-no}
      row.old-no {:side :old :no row.old-no}))

(fn scan-rows [rows from to step]
  (var at nil)
  (for [i from to step &until at]
    (let [row (. rows i)]
      (when (and row (row-ref row))
        (set at i))))
  at)

(fn nearest-row-ref [rows total start]
  (let [at (or (scan-rows rows start total 1) (scan-rows rows (- start 1) 1 -1))]
    (when at
      (values (row-ref (. rows at)) at))))

(fn anchor-start [state total]
  (math-util.clamp (if (= state.focus :right)
                       (or state.preview_cursor 1)
                       (+ (or state.preview_scroll 0) 1)) 1
                   total))

(fn anchored [state ref at]
  {:side ref.side :no ref.no :offset (- at (or state.preview_scroll 0))})

(fn capture-unified [state entry]
  (let [refs (preview.line-refs state entry)
        total (or state.preview_total 0)]
    (when (and refs (> total 0))
      (let [(ref at) (nearest-line-ref refs (preview.display-source-map state)
                                       total (anchor-start state total))]
        (when ref
          (anchored state ref at))))))

(fn capture-split [state]
  (let [rows (or state.split_rows [])
        total (length rows)]
    (when (> total 0)
      (let [(ref at) (nearest-row-ref rows total (anchor-start state total))]
        (when ref
          (anchored state ref at))))))

(fn capture [state entry]
  (if (preview.split? state entry)
      (capture-split state)
      (capture-unified state entry)))

(fn unified-target [refs ?source-map total anchor]
  (var at nil)
  (var best nil)
  (for [i 1 total &until (= 0 best)]
    (let [ref (line-ref refs ?source-map i)]
      (when (and ref (= ref.side anchor.side))
        (let [distance (math.abs (- ref.no anchor.no))]
          (when (or (= nil best) (< distance best))
            (set at i)
            (set best distance))))))
  at)

(fn split-target [rows anchor]
  (let [key (if (= anchor.side :old) :old-no :new-no)]
    (var at nil)
    (var best nil)
    (each [i row (ipairs rows) &until (= 0 best)]
      (let [no (. row key)]
        (when no
          (let [distance (math.abs (- no anchor.no))]
            (when (or (= nil best) (< distance best))
              (set at i)
              (set best distance))))))
    at))

(fn apply-target [state at offset]
  (let [total (math.max 1 (or state.preview_total 0))
        max-scroll (scroll-util.max-offset (or state.preview_total 0)
                                           (or state.preview_rows 1))
        scroll (math-util.clamp (- at (or offset 1)) 0 max-scroll)]
    (set state.preview_scroll scroll)
    (set state.preview_cursor (if (= state.focus :right)
                                  (math-util.clamp at 1 total)
                                  (+ scroll 1)))))

(fn take-anchor [state]
  (let [anchor state.preview_anchor]
    (set state.preview_anchor nil)
    anchor))

(fn restore-unified [state entry]
  (let [anchor (take-anchor state)]
    (when anchor
      (let [refs (preview.line-refs state entry)
            total (or state.preview_total 0)]
        (when (and refs (> total 0))
          (let [at (unified-target refs (preview.display-source-map state)
                                   total anchor)]
            (when at
              (apply-target state at anchor.offset))))))))

(fn restore-split [state]
  (let [anchor (take-anchor state)]
    (when anchor
      (let [at (split-target (or state.split_rows []) anchor)]
        (when at
          (apply-target state at anchor.offset))))))

{: capture : restore-split : restore-unified}
