(local git (require :git.core))
(local assets (require :preview.assets))
(local file-preview (require :preview.file))
(local format (require :preview.format))
(local folder-preview (require :preview.folder))
(local preview-key (require :preview.key))
(local split (require :preview.split))
(local preview-warm (require :preview.warm))
(local viewport (require :preview.viewport))
(local sys (require :platform.core))
(local tui (require :tui.core))
(local math-util (require :util.math))
(local scroll-util (require :util.scroll))

(import-macros {: set-fields} :state.macros)

(fn file-lines [state entry]
  (if (assets.asset? entry)
      (format.asset state entry)
      (let [content (file-preview.read entry.path)]
        (if (not content)
            (format.warning state (.. "Cannot read " entry.path))
            (file-preview.binary? content)
            (format.binary state entry.path)
            (let [body (file-preview.split-lines content)
                  body (if (> (length body) 0) body
                           (format.output-lines state "" false))
                  out (format.header state entry.path)]
              (each [_ line (ipairs body)]
                (table.insert out line))
              out)))))

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

(fn split-rows [state entry]
  (if (or (not entry) entry.untracked? (assets.asset? entry))
      []
      (let [key (.. (preview-key.for-entry state.revision entry
                                           state.full_context?)
                    "\0split")
            cached (. state.split_cache key)]
        (if cached
            cached
            (let [(output ok) (git.plain-diff-output state.revision entry
                                                     state.full_context?)
                  rows (if ok (split.parse-rows output) [])]
              (tset state.split_cache key rows)
              rows)))))

(fn splittable? [state entry]
  (split.splittable? (split-rows state entry)))

(fn split-active? [state]
  (and state.split_mode? state.split_rows (next state.split_rows) true))

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
  (scroll-util.max-offset (or state.preview_total 0) (row-count state)))

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
        (let [(display source-map) (viewport.lines-for-width state lines
                                                             visible cols)]
          (set state.preview_display_cache
               {: lines
                : visible
                : cols
                :split-ratio state.split_ratio
                :wrap? state.preview_wrap?
                : display
                :source lines
                :source-map source-map})
          display))))

(fn reset-scroll [state]
  (set-fields state [:preview_scroll 0] [:preview_cursor 1]
              [:preview_x_scroll 0] [:preview_x_max_scroll 0]
              [:preview_display_cache nil]))

(fn keep-cursor-visible [state]
  (let [visible (row-count state)
        cursor (or state.preview_cursor 1)
        scroll (or state.preview_scroll 0)
        scroll (if (< cursor (+ scroll 1)) (- cursor 1)
                   (> cursor (+ scroll visible)) (- cursor visible)
                   scroll)]
    (set state.preview_scroll (math-util.clamp scroll 0 (max-scroll state nil)))))

(fn move-cursor [state delta]
  (let [before (or state.preview_cursor 1)
        cursor (math-util.clamp (+ before delta) 1
                                (math.max 1 (or state.preview_total 0)))]
    (set state.preview_cursor cursor)
    (keep-cursor-visible state)
    (not (= before cursor))))

(fn focus-cursor [state]
  (set state.preview_cursor
       (math-util.clamp (+ (or state.preview_scroll 0) 1) 1
                        (math.max 1 (or state.preview_total 0)))))

(fn restore-cursor [state cursor scroll]
  (set state.preview_cursor
       (math-util.clamp (or cursor 1) 1 (math.max 1 (or state.preview_total 0))))
  (set state.preview_scroll
       (math-util.clamp (or scroll 0) 0 (max-scroll state nil)))
  (keep-cursor-visible state))

(fn cursor-jump [state line]
  (set state.preview_cursor
       (math-util.clamp (or line 1) 1 (math.max 1 (or state.preview_total 0))))
  (keep-cursor-visible state))

(fn display-lines [state]
  (or (and state.preview_display_cache state.preview_display_cache.display) []))

(fn display-source [state]
  (and state.preview_display_cache state.preview_display_cache.source))

(fn display-source-map [state]
  (and state.preview_display_cache state.preview_display_cache.source-map))

(fn cursor-top [state]
  (let [before (or state.preview_cursor 1)]
    (set state.preview_cursor 1)
    (keep-cursor-visible state)
    (not (= before 1))))

(fn cursor-bottom [state]
  (let [before (or state.preview_cursor 1)
        target (math.max 1 (or state.preview_total 0))]
    (set state.preview_cursor target)
    (keep-cursor-visible state)
    (not (= before target))))

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
  (let [max-scroll (scroll-util.max-offset (cached-max-line-width state lines)
                                           (math.max 0 width))]
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
  (scroll-util.info (or state.preview_scroll 0) (or state.preview_total 0)
                    (or state.preview_rows 0)))

{: lines
 : split-rows
 : splittable?
 : split-active?
 : apply-display-lines
 : cursor-top
 : cursor-bottom
 : cursor-jump
 : display-lines
 : display-source
 : display-source-map
 : focus-cursor
 : restore-cursor
 : move-cursor
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
