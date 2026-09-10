(local git (require :git.core))
(local blame (require :git.blame))
(local blame-colors (require :preview.blame-colors))
(local assets (require :preview.assets))
(local bat (require :platform.bat))
(local highlight (require :preview.highlight))
(local theme (require :tui.theme))
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

(fn highlight-on? [state]
  (if (and state.highlight? state.highlight_available?
           (theme.line-tints? state.theme))
      true
      false))

(fn side-path [entry side]
  (if (= side :old) (or entry.old_path entry.path) entry.path))

(fn side-source [state entry side]
  (let [(old-ref new-ref) (git.comparison-ref-targets state.revision)]
    (if (git.files? state.revision)
        (case (if (= side :old) entry.old_file entry.new_file)
          file {: file})
        (= side :old)
        (when (and (not= entry.kind "A") (not entry.untracked?))
          {:command (git.show-file-command old-ref (side-path entry :old))})
        (not= entry.kind "D")
        (if new-ref
            {:command (git.show-file-command new-ref entry.path)}
            {:file entry.path}))))

(fn highlight-side [state entry side last-line]
  (when (and (< 0 last-line) (highlight.within-cap? last-line))
    (case (side-source state entry side)
      source (highlight.line-map (bat.highlight-lines source
                                                      (side-path entry side)
                                                      last-line state.bat_theme)))))

(fn diff-highlight [state entry output]
  (when (highlight-on? state)
    (let [needed (highlight.needed-lines output)]
      {:old (highlight-side state entry :old needed.old)
       :new (highlight-side state entry :new needed.new)})))

(fn cached-diff-highlight [state entry key output]
  (let [cache state.preview_highlight_cache]
    (if (not cache) (diff-highlight state entry output)
        (not= nil (. cache key)) (or (. cache key) nil)
        (let [result (diff-highlight state entry output)]
          (tset cache key (or result false))
          result))))

(fn file-highlight [state path line-count]
  (when (and (highlight-on? state) (highlight.within-cap? line-count))
    (highlight.line-map (bat.highlight-lines {:file path} path nil
                                             state.bat_theme))))

(fn body-lines [state content ?role ?styled]
  (let [lines (file-preview.split-lines content)]
    (if ?role
        (icollect [i line (ipairs lines)]
          (case (highlight.styled-line ?styled i line)
            styled (theme.tint state.theme (highlight.tint-role ?role) styled)
            _ (if (= line "") line (tui.color state.theme ?role line))))
        ?styled
        (icollect [i line (ipairs lines)]
          (or (highlight.styled-line ?styled i line) line))
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
                  styled (file-highlight state entry.path
                                         (length (file-preview.split-lines content)))
                  body (body-lines state content role styled)
                  body-count (length body)
                  body (if (> body-count 0) body (format.empty-preview state))
                  out (format.header state entry.path entry)
                  numbers (when (> body-count 0)
                            (file-body-numbers (length out) body-count))]
              (each [_ line (ipairs body)]
                (table.insert out line))
              (values out numbers))))))

(fn cache-key [state entry]
  (preview-key.for-entry state.revision entry state.full_context?
                         state.hide_comments? (highlight-on? state)))

(fn diff-data [state entry full-context?]
  (let [(output ok) (git.plain-diff-output state.revision entry full-context?)]
    (if ok
        (format.diff-lines state output entry
                           (cached-diff-highlight state entry
                                                  (cache-key state entry) output))
        (values (format.warning state (sys.trim output)) nil))))

(fn entry-data [state entry]
  (if (assets.asset? entry) (format.asset state entry)
      entry.untracked? (file-lines state entry)
      (diff-data state entry state.full_context?)))

(fn store-entry-data [state key lines ?numbers ?refs]
  (tset state.preview_cache key lines)
  (when state.preview_numbers_cache
    (tset state.preview_numbers_cache key (or ?numbers false)))
  (when state.preview_line_refs_cache
    (tset state.preview_line_refs_cache key (or ?refs false))))

(fn load-entry [state entry]
  "Compute the preview for `entry`, fill the line, number, and ref caches, and
return (lines numbers refs)."
  (let [(lines numbers refs) (entry-data state entry)]
    (store-entry-data state (cache-key state entry) lines numbers refs)
    (values lines numbers refs)))

(fn lines [state entry]
  (if (not entry)
      (format.no-selection state)
      (let [cached (. state.preview_cache (cache-key state entry))]
        (if cached cached (pick-values 1 (load-entry state entry))))))

(fn line-numbers [state entry]
  (when (and entry (not (assets.asset? entry)))
    (let [cached (. (or state.preview_numbers_cache {}) (cache-key state entry))]
      (if (not= nil cached)
          cached
          (let [(_ numbers) (load-entry state entry)]
            numbers)))))

(fn line-refs [state entry]
  (when (and entry (not entry.untracked?) (not (assets.asset? entry)))
    (let [cached (. (or state.preview_line_refs_cache {})
                    (cache-key state entry))]
      (if (not= nil cached)
          cached
          (let [(_ _ refs) (load-entry state entry)]
            refs)))))

(fn warming? [state]
  (and state.preview_warm state.preview_warm.dir))

(fn warm-covers? [state]
  (and (warming? state) (not state.full_context?) (not state.hide_comments?)
       true))

(fn warm-covers-entry? [state entry]
  (and (warm-covers? state)
       (not= nil (. state.preview_warm.key-index (cache-key state entry)))))

;; Beyond this many disjoint ranges, blame the whole file instead of building a
;; giant `git blame -L ...` command line.
(local max-blame-ranges 256)

(fn ranges-signature [ranges]
  (table.concat (icollect [_ r (ipairs ranges)] (.. (. r 1) "," (. r 2))) ";"))

(fn blame-key [state entry side signature]
  (.. state.revision "\0" (or entry.path "") "\0" (or entry.old_path "") "\0"
      (tostring side) "\0" (or signature "")))

(local no-labels {})

(fn blame-request [state entry side ?line-numbers]
  "The cache key and `git blame -L` ranges for one side of an entry."
  (let [ranges (when ?line-numbers (blame.ranges ?line-numbers))
        empty? (and ranges (= 0 (length ranges)))
        ranges (if (and ranges (> (length ranges) max-blame-ranges)) nil ranges)
        signature (if ranges (ranges-signature ranges) "")]
    {:key (blame-key state entry side signature) : ranges : empty?}))

(fn cached-blame [state key]
  (. (or state.preview_blame_cache {}) key))

(fn request-labels [state entry side request]
  "Blame labels by line number for one request. While a blame-warming run covers
this entry, a cache miss returns the shared empty table instead of blocking on
git; the import fills the cache."
  (if request.empty?
      no-labels
      (let [cached (cached-blame state request.key)]
        (if cached cached
            (and state.preview_warm state.preview_warm.blame?
                 (warm-covers-entry? state entry)) no-labels
            (let [lines (git.blame-lines state.revision entry side
                                         request.ranges)]
              (when state.preview_blame_cache
                (tset state.preview_blame_cache request.key lines))
              lines)))))

(fn blame-lines [state entry side ?line-numbers]
  (request-labels state entry side
                  (blame-request state entry side ?line-numbers)))

(fn side-line-numbers [refs side]
  (icollect [_ ref (ipairs (or refs []))]
    (when (and ref (= ref.side side)) ref.no)))

(fn split-side-numbers [rows side]
  (icollect [_ row (ipairs (or rows []))]
    (. row (if (= side :old) :old-no :new-no))))

(fn blame-requests [state field entry source numbers-for]
  "Both sides' blame requests for `source`, a refs or split rows table, kept in
`state[field]` so a frame that sees the same table does not rebuild the ranges."
  (let [memo (. state field)]
    (if (and memo (= memo.source source) (= memo.entry entry)
             (= memo.revision state.revision))
        memo
        (let [memo {: source
                    : entry
                    :revision state.revision
                    :old (blame-request state entry :old
                                        (numbers-for source :old))
                    :new (blame-request state entry :new
                                        (numbers-for source :new))}]
          (tset state field memo)
          memo))))

(fn requested-blame [state entry requests]
  (values (request-labels state entry :old requests.old)
          (request-labels state entry :new requests.new)))

(fn refs-blame-lines [state entry refs]
  "Blame labels for the old and new side of unified line refs."
  (if (or (not entry) (not refs))
      (values no-labels no-labels)
      (requested-blame state entry
                       (blame-requests state :preview_blame_requests entry refs
                                       side-line-numbers))))

(fn split-blame-lines [state entry rows]
  "Blame labels for the old and new side of split rows."
  (if (or (not entry) (not rows))
      (values no-labels no-labels)
      (requested-blame state entry
                       (blame-requests state :split_blame_requests entry rows
                                       split-side-numbers))))

(fn blame-cached? [state entry side numbers]
  (or (= 0 (length numbers))
      (not= nil
            (cached-blame state (. (blame-request state entry side numbers)
                                   :key)))))

(fn blame-candidate? [entry]
  (and entry (not entry.untracked?) (not (assets.asset? entry)) true))

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

(fn gutters-with-blame [state numbers refs old-blame new-blame]
  (when (or (and state.show_numbers? numbers) (and state.show_blame? refs))
    (let [number-w (if state.show_numbers? (number-width numbers) 0)
          blame-w (if state.show_blame? (blame-width refs old-blame new-blame)
                      0)
          label-for (fn [ref]
                      (and state.show_blame? ref ref.no
                           (. (if (= ref.side :old) old-blame new-blame) ref.no)))
          slots (blame-colors.assign (icollect [_ ref (ipairs (or refs []))]
                                       (label-for ref)))
          source (or refs numbers)]
      (icollect [i _item (ipairs source)]
        (let [ref (and refs (. refs i))
              number (and state.show_numbers? numbers (. numbers i))
              blame (label-for ref)]
          (if (or number blame)
              (let [number-text (if (> number-w 0)
                                    (padded (and number (tostring number))
                                            number-w)
                                    "")
                    sep (if (and (> number-w 0) (> blame-w 0)) " " "")
                    blame-text (if (> blame-w 0)
                                   (padded-right (blame-colors.colorize state.theme
                                                                        slots
                                                                        blame)
                                                 blame-w)
                                   "")]
                (if state.show_blame?
                    {:full (.. number-text sep blame-text)}
                    (.. number-text sep blame-text)))
              false))))))

(fn line-gutters [state entry numbers refs]
  (let [(old-blame new-blame) (if state.show_blame?
                                  (refs-blame-lines state entry refs)
                                  (values no-labels no-labels))]
    (gutters-with-blame state numbers refs old-blame new-blame)))

(fn cached-gutters? [state cache numbers refs old-blame new-blame]
  (and cache (= cache.numbers numbers) (= cache.refs refs)
       (= cache.old-blame old-blame) (= cache.new-blame new-blame)
       (= cache.theme state.theme)
       (= cache.numbers? (and state.show_numbers? true))
       (= cache.blame? (and state.show_blame? true))))

(fn cached-line-gutters [state entry numbers refs]
  "The unified gutters for `entry`, reused across frames while the numbers, refs,
blame labels, and toggles they were built from are unchanged."
  (let [(old-blame new-blame) (if state.show_blame?
                                  (refs-blame-lines state entry refs)
                                  (values no-labels no-labels))
        cache state.preview_gutter_cache]
    (if (cached-gutters? state cache numbers refs old-blame new-blame)
        cache.gutters
        (let [gutters (gutters-with-blame state numbers refs old-blame
                                          new-blame)]
          (set state.preview_gutter_cache
               {: numbers
                : refs
                : old-blame
                : new-blame
                :theme state.theme
                :numbers? (and state.show_numbers? true)
                :blame? (and state.show_blame? true)
                : gutters})
          gutters))))

(fn split-key [state entry]
  (.. (cache-key state entry) "\0split"))

(fn compute-split-rows [state entry key]
  (let [(output ok) (git.plain-diff-output state.revision entry
                                           state.full_context?)
        rows (if ok
                 (split.parse-rows output state.revision_old_label
                                   state.revision_new_label state.hide_comments?
                                   (cached-diff-highlight state entry
                                                          (cache-key state
                                                                     entry)
                                                          output))
                 [])]
    (tset state.split_cache key rows)
    rows))

(fn split-rows [state entry]
  (if (or (not entry) entry.untracked? (assets.asset? entry))
      []
      (let [key (split-key state entry)
            cached (. state.split_cache key)]
        (if cached cached
            (warm-covers? state) []
            (compute-split-rows state entry key)))))

(fn split-blame-needed? [state entry]
  (and state.split_mode? (= entry.kind "M")))

(fn split-blame-ready? [state entry]
  (let [rows (. state.split_cache (split-key state entry))]
    (and rows (blame-cached? state entry :old (split-side-numbers rows :old))
         (blame-cached? state entry :new (split-side-numbers rows :new)) true)))

(fn blame-ready? [state entry key]
  (let [refs (. (or state.preview_line_refs_cache {}) key)]
    (and (not= nil refs)
         (blame-cached? state entry :old (side-line-numbers (or refs []) :old))
         (blame-cached? state entry :new (side-line-numbers (or refs []) :new))
         (or (not (split-blame-needed? state entry))
             (split-blame-ready? state entry)) true)))

(fn gutters-ready? [state entry key]
  (if state.show_blame? (blame-ready? state entry key)
      state.show_numbers? (not= nil (. (or state.preview_numbers_cache {}) key))
      true))

(fn ready? [state entry]
  (or (not entry) entry.untracked? (assets.asset? entry)
      (let [key (cache-key state entry)]
        (and (not= nil (. state.preview_cache key))
             (or (not state.split_mode?) (not= entry.kind "M")
                 (not= nil (. state.split_cache (split-key state entry))))
             (gutters-ready? state entry key) true))))

(fn warm-highlight [state]
  "The highlight settings a warm run passes to its workers."
  {:on? (highlight-on? state)
   :bat-theme state.bat_theme
   :background (and state.theme state.theme.background)})

(fn warm-caches [state]
  "The app caches a warm import fills, keyed the same way the worker output is."
  {:lines state.preview_cache
   :split state.split_cache
   :numbers state.preview_numbers_cache
   :refs state.preview_line_refs_cache
   :blame state.preview_blame_cache})

(fn blame-missing? [state entry]
  (and (blame-candidate? entry)
       (not (blame-ready? state entry (cache-key state entry)))))

(fn warm-missing-entries [state entries]
  "Entries the background workers should compute: previews not yet cached, plus
entries whose blame is not cached while blame is shown."
  (icollect [_ entry (ipairs entries)]
    (when (or (= nil (. state.preview_cache (cache-key state entry)))
              (and state.show_blame? (blame-missing? state entry)))
      entry)))

(fn warm-blame [state entry refs split-rows]
  "Blame both sides of an entry for the line sets the unified and split views
ask for, so their cache keys are ready when the output is imported."
  (when state.show_blame?
    (let [out {}]
      (each [_ [side numbers] (ipairs [[:old (side-line-numbers refs :old)]
                                       [:new (side-line-numbers refs :new)]
                                       [:old
                                        (split-side-numbers split-rows :old)]
                                       [:new
                                        (split-side-numbers split-rows :new)]])]
        (let [request (blame-request state entry side numbers)]
          (when (and (< 0 (length numbers)) (not (. out request.key)))
            (tset out request.key
                  (git.blame-lines state.revision entry side request.ranges)))))
      out)))

(fn warm-diff-entry [state entry]
  (let [(output ok) (git.plain-diff-output state.revision entry
                                           state.full_context?)]
    (if ok
        (let [styled (diff-highlight state entry output)
              (lines numbers refs) (format.diff-lines state output entry styled)
              split-rows (if (= entry.kind "M")
                             (split.parse-rows output state.revision_old_label
                                               state.revision_new_label
                                               state.hide_comments? styled)
                             [])]
          {: lines
           :numbers (or numbers false)
           :refs (or refs false)
           :split split-rows
           :blame (warm-blame state entry refs split-rows)})
        {:lines (format.warning state (sys.trim output))
         :numbers false
         :refs false
         :split []})))

(fn warm-entry [state entry]
  (if (not entry) {:lines (format.no-selection state) :split []}
      (assets.asset? entry) {:lines (format.asset state entry) :split []}
      entry.untracked? (let [(lines numbers) (file-lines state entry)]
                         {: lines :numbers (or numbers false) :split []})
      (warm-diff-entry state entry)))

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
      (let [key (cache-key state entry)
            cached (. state.preview_cache key)]
        (if cached cached
            (warm-covers? state) (loading-lines state)
            (lines state entry)))))

(fn prepare-entry [state entry]
  (preview-warm.import-entry state.preview_warm (warm-caches state)
                             state.revision entry))

(fn listing-row? [state row]
  (and (= state.view_mode :tree) row (= row.type :file) row.unchanged row.path))

(fn selection-gutters [state entry]
  (when (or state.show_numbers? state.show_blame?)
    (cached-line-gutters state entry (line-numbers state entry)
                         (line-refs state entry))))

(fn selection-lines [state selected-entry selected-row]
  (if (and (= state.view_mode :tree) selected-row (= selected-row.type :folder))
      (values (folder-preview.lines state selected-row) nil)
      (listing-row? state selected-row)
      (values (file-lines state {:path selected-row.path}) nil)
      (values (nonblocking-lines state selected-entry)
              (selection-gutters state selected-entry))))

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
 : split-blame-lines
 : cache-split
 : warm-caches
 : warm-entry
 : warm-highlight
 : highlight-on?
 : warm-missing-entries
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
 : ready?
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
