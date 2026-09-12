(local text-highlight (require :tui.text-highlight))
(local theme (require :tui.theme))
(local txt (require :tui.text))

(local max-lines 5000)

(fn within-cap? [?last-line]
  (or (= nil ?last-line) (<= ?last-line max-lines)))

(fn line-map [?lines]
  (when ?lines
    (collect [i line (ipairs ?lines)]
      (values i line))))

(fn styled-line [?map ?no raw]
  (let [styled (and ?map ?no raw (not= raw "") (. ?map ?no))]
    (when (and styled (= raw (txt.strip-ansi styled)))
      styled)))

(fn side-map [?highlight side]
  (and ?highlight (. ?highlight side)))

(local tint-roles {:status-added :line-added
                   :status-deleted :line-deleted
                   :comment-added :line-added
                   :comment-deleted :line-deleted})

(local emphasis-tints
       {:emphasis-added :emphasis-tint-added
        :emphasis-deleted :emphasis-tint-deleted})

(local emphasis-ends {:emphasis-added :line-added
                      :emphasis-deleted :line-deleted})

(fn tint-role [role]
  (. tint-roles role))

(fn emphasis-tint [style-key]
  (. emphasis-tints style-key))

(fn emphasis-end [style-key]
  (. emphasis-ends style-key))

(fn visible-ranges [raw ranges]
  (icollect [_ r (ipairs ranges)]
    (when (< r.from r.to)
      {:first (+ 1 (txt.visible-length (raw:sub 1 (- r.from 1))))
       :last (txt.visible-length (raw:sub 1 (- r.to 1)))})))

(fn emphasize-styled [theme-table styled raw ?ranges style-key]
  (let [ranges (visible-ranges raw (or ?ranges []))
        start (theme.style-for theme-table (emphasis-tint style-key))
        stop (theme.style-for theme-table (emphasis-end style-key))]
    (if (and (next ranges) start stop)
        (text-highlight.apply styled ranges start stop)
        styled)))

(fn hunk-extent [line]
  (let [(old old-count new new-count) (line:match "^@@ %-(%d+),?(%d*) %+(%d+),?(%d*)")]
    (when old
      (values (+ (tonumber old) (math.max 0 (- (or (tonumber old-count) 1) 1)))
              (+ (tonumber new) (math.max 0 (- (or (tonumber new-count) 1) 1)))))))

(fn needed-lines [diff-text]
  (accumulate [needed {:old 0 :new 0} line (string.gmatch (or diff-text "")
                                                          "[^\r\n]+")]
    (case (hunk-extent line)
      (old new) {:old (math.max needed.old old) :new (math.max needed.new new)}
      _ needed)))

{: emphasis-end
 : emphasis-tint
 : emphasize-styled
 : line-map
 : max-lines
 : needed-lines
 : side-map
 : styled-line
 : tint-role
 : within-cap?}
