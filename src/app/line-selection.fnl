(local tui (require :tui.core))

(fn active? [state]
  (not= nil state.preview_selection_anchor))

(fn range [anchor cursor]
  (let [c (or cursor 1)]
    (if anchor
        (values (math.min anchor c) (math.max anchor c))
        (values c c))))

(fn clamped-range [display anchor cursor]
  (let [total (length display)
        (lo hi) (range anchor cursor)]
    (values (math.max 1 lo) (math.min total hi))))

;; Resolve a display-row range to the unique source (logical) line indices it
;; covers, so a wrapped line counts once. Without a map, display rows are the
;; source lines.
(fn source-indices [source-map lo hi]
  (let [seen {}
        out []]
    (for [i lo hi]
      (let [src (if source-map (. source-map i) i)]
        (when (and src (not (. seen src)))
          (tset seen src true)
          (table.insert out src))))
    out))

(fn selected-text [display anchor cursor ?source ?source-map]
  (let [(lo hi) (clamped-range display anchor cursor)
        source (or ?source display)
        indices (source-indices ?source-map lo hi)]
    (table.concat (icollect [_ i (ipairs indices)]
                    (tui.strip-ansi (. source i))) "\n")))

(fn line-count [display anchor cursor ?source-map]
  (let [(lo hi) (clamped-range display anchor cursor)]
    (length (source-indices ?source-map lo hi))))

(fn start [state]
  (set state.preview_selection_anchor (or state.preview_cursor 1)))

(fn stop [state]
  (set state.preview_selection_anchor nil))

{: active? : line-count : range : selected-text : start : stop}
