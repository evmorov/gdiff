(local git (require :git.core))
(local assets (require :preview.assets))
(local file-preview (require :preview.file))
(local format (require :preview.format))
(local folder-preview (require :preview.folder))
(local preview-key (require :preview.key))
(local preview-warm (require :preview.warm))
(local viewport (require :preview.viewport))
(local sys (require :platform.core))
(local tui (require :tui.core))
(local math-util (require :util.math))

(import-macros {: set-fields} :state.macros)

(fn file-lines [state entry]
  (if (assets.asset? entry)
      (format.asset state entry)
      (let [content (file-preview.read entry.path)]
        (if content
            (let [body (file-preview.split-lines content)
                  body (if (> (length body) 0) body
                           (format.output-lines state "" false))
                  out (format.header state entry.path)]
              (each [_ line (ipairs body)]
                (table.insert out line))
              out)
            (format.warning state (.. "Cannot read " entry.path))))))

(fn lines [state entry]
  (if (not entry)
      (format.no-selection state)
      (let [full-context? state.full_context?
            key (preview-key.for-entry state.revision entry full-context?)
            cached (. state.preview_cache key)]
        (if cached
            cached
            (assets.asset? entry)
            (let [lines (format.asset state entry)]
              (tset state.preview_cache key lines)
              lines)
            entry.untracked?
            (let [lines (file-lines state entry)]
              (tset state.preview_cache key lines)
              lines)
            (let [(output ok filtered?) (git.preview-output state.preview_context
                                                            state.revision entry
                                                            full-context?)
                  lines (if ok
                            (format.output-lines state output filtered?)
                            (format.warning state (sys.trim output)))]
              (tset state.preview_cache key lines)
              lines)))))

(fn warming? [state]
  (and state.preview_warm state.preview_warm.dir))

(fn loading-lines [state]
  (format.loading state))

(fn nonblocking-lines [state entry]
  (if (not entry)
      (format.no-selection state)
      (let [full-context? state.full_context?
            key (preview-key.for-entry state.revision entry full-context?)
            cached (. state.preview_cache key)]
        (if cached cached
            (and (warming? state) (not full-context?)) (loading-lines state)
            (lines state entry)))))

(fn prepare-entry [state entry]
  (preview-warm.import-entry state.preview_warm state.preview_cache
                             state.revision entry))

(fn listing-row? [state row]
  (and (= state.view_mode :tree) row (= row.type :file) row.unchanged row.path))

(fn selection-lines [state selected-entry selected-row]
  (if (and (= state.view_mode :tree) selected-row (= selected-row.type :folder))
      (folder-preview.lines state selected-row)
      (listing-row? state selected-row)
      (file-lines state {:path selected-row.path})
      (nonblocking-lines state selected-entry)))

(fn row-count [state]
  (or state.preview_rows 1))

(fn visible-count [visible]
  (math.max 1 (or visible 1)))

(fn page-step [state]
  (math.max 1 (math.floor (/ (row-count state) 2))))

(fn max-scroll [state _entry]
  (math.max 0 (- (or state.preview_total 0) (row-count state))))

(fn set-scroll [state entry scroll]
  (let [before (or state.preview_scroll 0)
        after (math-util.clamp scroll 0 (max-scroll state entry))]
    (set state.preview_scroll after)
    (not (= before after))))

(fn apply-display-lines [state lines visible]
  (let [scroll-state (viewport.scroll-state lines (visible-count visible)
                                            state.preview_scroll)]
    (set-fields state [:preview_rows scroll-state.visible]
                [:preview_total scroll-state.total]
                [:preview_scroll scroll-state.offset])
    scroll-state))

(fn visible-display-lines [state lines visible]
  (viewport.visible-lines lines
                          (viewport.scroll-state lines (visible-count visible)
                                                 state.preview_scroll)))

(fn display-lines-for-width [state lines visible cols]
  (let [cache-key {: lines
                   : visible
                   : cols
                   :split-ratio state.split_ratio
                   :wrap? state.preview_wrap?}
        cache state.preview_display_cache]
    (if (and cache (= cache.lines cache-key.lines)
             (= cache.visible cache-key.visible) (= cache.cols cache-key.cols)
             (= cache.split-ratio cache-key.split-ratio)
             (= cache.wrap? cache-key.wrap?))
        cache.display
        (let [display (viewport.lines-for-width state lines visible cols)]
          (set state.preview_display_cache
               {: lines
                : visible
                : cols
                :split-ratio state.split_ratio
                :wrap? state.preview_wrap?
                : display})
          display))))

(fn reset-scroll [state]
  (set-fields state [:preview_scroll 0] [:preview_x_scroll 0]
              [:preview_x_max_scroll 0] [:preview_display_cache nil]))

(fn scroll [state entry delta]
  (set-scroll state entry (+ (or state.preview_scroll 0) delta)))

(fn scroll-page-down [state entry]
  (scroll state entry (page-step state)))

(fn scroll-page-up [state entry]
  (scroll state entry (- (page-step state))))

(fn scroll-horizontal [state delta]
  (let [before (or state.preview_x_scroll 0)
        after (math-util.clamp (+ before delta) 0
                               (or state.preview_x_max_scroll 0))]
    (set state.preview_x_scroll after)
    (not (= before after))))

(fn max-line-width [lines]
  (accumulate [width 0 _ line (ipairs (or lines []))]
    (math.max width (tui.visible-length line))))

(fn cached-max-line-width [state lines]
  (if (= state.preview_width_lines lines)
      (or state.preview_width 0)
      (let [width (max-line-width lines)]
        (set-fields state [:preview_width_lines lines] [:preview_width width])
        width)))

(fn set-horizontal-scroll-limit [state lines width]
  (let [max-scroll (math.max 0
                             (- (cached-max-line-width state lines)
                                (math.max 0 width)))]
    (set-fields state [:preview_x_max_scroll max-scroll]
                [:preview_x_scroll
                 (math-util.clamp (or state.preview_x_scroll 0) 0 max-scroll)])))

(fn apply-horizontal-scroll-limit [state lines cols vertical-scroll?]
  (if state.preview_wrap?
      (set-horizontal-scroll-limit state [] 0)
      (set-horizontal-scroll-limit state lines
                                   (viewport.content-width state.split_ratio
                                                           cols vertical-scroll?))))

(fn visible-lines [state entry visible ?opts]
  (let [lines (if (and ?opts ?opts.nonblocking?)
                  (nonblocking-lines state entry)
                  (lines state entry))]
    (apply-display-lines state lines visible)
    (visible-display-lines state lines visible)))

(fn scroll-info [state]
  (let [visible (or state.preview_rows 0)
        total (or state.preview_total 0)]
    (when (> total visible)
      {:offset (or state.preview_scroll 0) : visible : total})))

{: lines
 : apply-display-lines
 : nonblocking-lines
 : page-step
 : prepare-entry
 : reset-scroll
 : scroll
 : scroll-info
 : scroll-horizontal
 : scroll-page-down
 : scroll-page-up
 : selection-lines
 : apply-horizontal-scroll-limit
 : cached-max-line-width
 : display-lines-for-width
 : max-line-width
 : set-horizontal-scroll-limit
 : visible-display-lines
 : visible-count
 : visible-lines}
