(local git (require :git.core))
(local blame (require :git.blame))
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

(fn body-lines [state content ?role]
  (let [lines (file-preview.split-lines content)]
    (if ?role
        (icollect [_ line (ipairs lines)]
          (if (= line "") line (tui.color state.theme ?role line)))
        lines)))

(fn file-body-numbers [header-count body-count]
  (let [numbers []]
    (for [_ 1 header-count]
      (table.insert numbers false))
    (for [i 1 body-count]
      (table.insert numbers i))
    numbers))

(fn file-lines [state entry]
  (if (assets.asset? entry)
      (format.asset state entry)
      (let [content (file-preview.read entry.path)]
        (if (not content)
            (format.warning state (.. "Cannot read " entry.path))
            (file-preview.binary? content)
            (format.binary state entry.path)
            (let [role (when entry.untracked? :status-added)
                  body (body-lines state content role)
                  body-count (length body)
                  body (if (> body-count 0) body (format.empty-preview state))
                  out (format.header state entry.path)
                  numbers (when (> body-count 0)
                            (file-body-numbers (length out) body-count))]
              (each [_ line (ipairs body)]
                (table.insert out line))
              (values out numbers))))))

(fn diff-data [state entry full-context?]
  (let [(output ok) (git.plain-diff-output state.revision entry full-context?)]
    (if ok
        (format.diff-lines state output)
        (values (format.warning state (sys.trim output)) nil))))

(fn cache-key [state entry]
  (preview-key.for-entry state.revision entry state.full_context?))

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
            (let [(lines numbers) (file-lines state entry)]
              (tset state.preview_cache key lines)
              (when state.preview_numbers_cache
                (tset state.preview_numbers_cache key (or numbers false)))
              lines)
            (let [(lines numbers refs) (diff-data state entry full-context?)]
              (tset state.preview_cache key lines)
              (when state.preview_numbers_cache
                (tset state.preview_numbers_cache key (or numbers false)))
              (when state.preview_line_refs_cache
                (tset state.preview_line_refs_cache key (or refs false)))
              lines)))))

(fn line-numbers [state entry]
  (if (or (not entry) (assets.asset? entry)) nil
      (let [key (cache-key state entry)
            cached (. (or state.preview_numbers_cache {}) key)]
        (if (not (= nil cached)) cached entry.untracked?
            (let [(_ numbers) (file-lines state entry)]
              (when state.preview_numbers_cache
                (tset state.preview_numbers_cache key (or numbers false)))
              numbers) (let [(_ numbers refs) (diff-data state entry
                                                                    state.full_context?)]
                                    (when state.preview_numbers_cache
                                      (tset state.preview_numbers_cache key
                                            (or numbers false)))
                                    (when state.preview_line_refs_cache
                                      (tset state.preview_line_refs_cache key
                                            (or refs false)))
                                    numbers)))))

(fn line-refs [state entry]
  (if (or (not entry) entry.untracked? (assets.asset? entry))
      nil
      (let [key (cache-key state entry)
            cached (. (or state.preview_line_refs_cache {}) key)]
        (if (not (= nil cached))
            cached
            (let [(_ numbers refs) (diff-data state entry state.full_context?)]
              (when state.preview_numbers_cache
                (tset state.preview_numbers_cache key (or numbers false)))
              (when state.preview_line_refs_cache
                (tset state.preview_line_refs_cache key (or refs false)))
              refs)))))

;; Beyond this many disjoint ranges, blame the whole file instead of building a
;; giant `git blame -L ...` command line.
(local max-blame-ranges 256)

(fn ranges-signature [ranges]
  (table.concat (icollect [_ r (ipairs ranges)] (.. (. r 1) "," (. r 2))) ";"))

(fn blame-key [state entry side signature]
  (.. state.revision "\0" (or entry.path "") "\0" (or entry.old_path "") "\0"
      (tostring side) "\0" (or signature "")))

(fn blame-lines [state entry side ?line-numbers]
  (if (and ?line-numbers (= 0 (length ?line-numbers)))
      {}
      (let [ranges (when ?line-numbers (blame.ranges ?line-numbers))
            ranges (if (and ranges (> (length ranges) max-blame-ranges)) nil
                       ranges)
            signature (if ranges (ranges-signature ranges) "")
            key (blame-key state entry side signature)
            cached (. (or state.preview_blame_cache {}) key)]
        (if cached
            cached
            (let [lines (git.blame-lines state.revision entry side ranges)]
              (when state.preview_blame_cache
                (tset state.preview_blame_cache key lines))
              lines)))))

(fn side-line-numbers [refs side]
  (icollect [_ ref (ipairs (or refs []))]
    (when (and ref (= ref.side side)) ref.no)))

(fn number-width [numbers]
  (accumulate [width 0 _ number (ipairs (or numbers []))]
    (math.max width (if number (length (tostring number)) 0))))

(fn blame-width [refs old-blame new-blame]
  (accumulate [width 0 _ ref (ipairs (or refs []))]
    (let [line (and ref ref.no)
          label (and line (. (if (= ref.side :old) old-blame new-blame) line))]
      (math.max width (if label (tui.visible-length label) 0)))))

(fn padded [text width]
  (let [text (or text "")]
    (.. (string.rep " " (math.max 0 (- width (tui.visible-length text)))) text)))

(fn padded-right [text width]
  (let [text (or text "")]
    (.. text (string.rep " " (math.max 0 (- width (tui.visible-length text)))))))

(fn line-gutters [state entry numbers refs]
  (when (or (and state.show_numbers? numbers) (and state.show_blame? refs))
    (let [number-w (if state.show_numbers? (number-width numbers) 0)
          old-blame (if state.show_blame?
                        (blame-lines state entry :old
                                     (side-line-numbers refs :old))
                        {})
          new-blame (if state.show_blame?
                        (blame-lines state entry :new
                                     (side-line-numbers refs :new))
                        {})
          blame-w (if state.show_blame? (blame-width refs old-blame new-blame)
                      0)
          source (or refs numbers)]
      (icollect [i _item (ipairs source)]
        (let [ref (and refs (. refs i))
              number (and state.show_numbers? numbers (. numbers i))
              blame (and state.show_blame? ref ref.no
                         (. (if (= ref.side :old) old-blame new-blame) ref.no))]
          (if (or number blame)
              (let [number-text (if (> number-w 0)
                                    (padded (and number (tostring number))
                                            number-w)
                                    "")
                    sep (if (and (> number-w 0) (> blame-w 0)) " " "")
                    blame-text (if (> blame-w 0) (padded-right blame blame-w)
                                   "")]
                (if state.show_blame?
                    {:full (.. number-text sep blame-text)}
                    (.. number-text sep blame-text)))
              false))))))

(fn warming? [state]
  (and state.preview_warm state.preview_warm.dir))

(fn split-key [state entry]
  (.. (preview-key.for-entry state.revision entry state.full_context?)
      "\0split"))

(fn compute-split-rows [state entry key]
  (let [(output ok) (git.plain-diff-output state.revision entry
                                           state.full_context?)
        rows (if ok
                 (split.parse-rows output state.revision_old_label
                                   state.revision_new_label)
                 [])]
    (tset state.split_cache key rows)
    rows))

(fn split-rows [state entry]
  (if (or (not entry) entry.untracked? (assets.asset? entry))
      []
      (let [key (split-key state entry)
            cached (. state.split_cache key)]
        (if cached cached
            (and (warming? state) (not state.full_context?)) []
            (compute-split-rows state entry key)))))

(fn warm-entry [state entry]
  (if (not entry)
      {:lines (format.no-selection state) :split []}
      (assets.asset? entry)
      {:lines (format.asset state entry) :split []}
      entry.untracked?
      {:lines (file-lines state entry) :split []}
      (let [(output ok) (git.plain-diff-output state.revision entry
                                               state.full_context?)]
        (if ok
            (let [(lines _numbers) (format.diff-lines state output)]
              {: lines
               :split (if (= entry.kind "M")
                          (split.parse-rows output state.revision_old_label
                                            state.revision_new_label)
                          [])})
            {:lines (format.warning state (sys.trim output)) :split []}))))

(fn cache-split [state entry]
  (when (and entry (= entry.kind "M") (not entry.untracked?)
             (not (assets.asset? entry)))
    (let [key (split-key state entry)]
      (when (not (. state.split_cache key))
        (compute-split-rows state entry key)))))

(fn splittable? [state entry]
  (and entry (= entry.kind "M") (split.splittable? (split-rows state entry))))

(fn split? [state entry]
  (and state.split_mode? (splittable? state entry)))

(fn split-active? [state]
  (and state.split_mode? state.split_rows (next state.split_rows) true))

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
                             state.revision entry state.split_cache))

(fn listing-row? [state row]
  (and (= state.view_mode :tree) row (= row.type :file) row.unchanged row.path))

(fn selection-lines [state selected-entry selected-row]
  (if (and (= state.view_mode :tree) selected-row (= selected-row.type :folder))
      (values (folder-preview.lines state selected-row) nil)
      (listing-row? state selected-row)
      (values (file-lines state {:path selected-row.path}) nil)
      (let [lines (nonblocking-lines state selected-entry)
            numbers (line-numbers state selected-entry)
            refs (line-refs state selected-entry)]
        (values lines (line-gutters state selected-entry numbers refs)))))

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

(fn styled-gutters [state gutters]
  (when gutters
    (icollect [_ g (ipairs gutters)]
      (tui.color state.theme :faint g))))

(fn display-lines-for-width [state lines numbers visible cols]
  (let [cache state.preview_display_cache]
    (if (and cache (= cache.lines lines) (= cache.visible visible)
             (= cache.cols cols) (= cache.split-ratio state.split_ratio)
             (= cache.wrap? state.preview_wrap?)
             (= cache.numbers? (and state.show_numbers? true))
             (= cache.blame? (and state.show_blame? true)))
        cache.display
        (let [(display source-map gutters) (viewport.lines-for-width state
                                                                     lines
                                                                     numbers
                                                                     visible
                                                                     cols)]
          (set state.preview_display_cache
               {: lines
                : visible
                : cols
                :split-ratio state.split_ratio
                :wrap? state.preview_wrap?
                :numbers? (and state.show_numbers? true)
                :blame? (and state.show_blame? true)
                : display
                :source lines
                :source-map source-map
                :gutters (styled-gutters state gutters)})
          display))))

(fn reset-scroll [state]
  (set-fields state [:preview_scroll 0] [:preview_cursor 1]
              [:preview_x_scroll 0] [:preview_x_max_scroll 0]
              [:preview_display_cache nil] [:split_display_cache nil]
              [:preview_anchor nil]))

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

(fn restore-scroll [state scroll]
  (set state.preview_scroll
       (math-util.clamp (or scroll 0) 0 (max-scroll state nil)))
  (focus-cursor state))

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

(fn display-gutters [state]
  (and state.preview_display_cache state.preview_display_cache.gutters))

(fn visible-display-gutters [state gutters visible]
  (when gutters
    (viewport.visible-lines gutters
                            (viewport.scroll-state gutters
                                                   (visible-count visible)
                                                   state.preview_scroll))))

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
 : blame-lines
 : cache-split
 : warm-entry
 : splittable?
 : split?
 : split-active?
 : apply-display-lines
 : cursor-top
 : cursor-bottom
 : cursor-jump
 : display-lines
 : display-gutters
 : display-source
 : display-source-map
 : line-gutters
 : line-numbers
 : line-refs
 : visible-display-gutters
 : focus-cursor
 : restore-cursor
 : restore-scroll
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
