(local ansi (require :tui.ansi))
(local colors (require :tui.colors))

(local base-styles {:muted "\27[2m"
                    :selected-marker "\27[1m"
                    :status-added "\27[32m"
                    :status-modified "\27[33m"
                    :status-deleted "\27[31m"
                    :comment-added "\27[38;5;28m"
                    :comment-deleted "\27[38;5;124m"
                    :moved "\27[38;5;208m"
                    :status-renamed "\27[36m"
                    :status-copied "\27[35m"
                    :status-untracked "\27[90m"
                    :notice "\27[90m"
                    :faint "\27[38;5;242m"
                    :warning "\27[31m"
                    :search-match "\27[1;4m"
                    :search-match-end "\27[22;24m"
                    :emphasis-deleted "\27[48;5;224m"
                    :emphasis-added "\27[48;5;194m"
                    :whitespace-deleted "\27[41m"
                    :whitespace-added "\27[42m"
                    :emphasis-end "\27[49m"})

(local green {:r 0 :g 200 :b 0})
(local red {:r 255 :g 0 :b 0})
(local line-tint-amount 0.12)
(local emphasis-tint-amount 0.3)

(fn derived-styles [background-rgb]
  {:search-match (.. (colors.background-style background-rgb 0.28) "\27[1m")
   :search-match-end ansi.reset-style
   :line-added (colors.tint-style background-rgb green line-tint-amount)
   :line-deleted (colors.tint-style background-rgb red line-tint-amount)
   :emphasis-tint-added (colors.tint-style background-rgb green
                                           emphasis-tint-amount)
   :emphasis-tint-deleted (colors.tint-style background-rgb red
                                             emphasis-tint-amount)})

(fn copy [styles]
  (collect [role style (pairs styles)]
    (values role style)))

(fn styles [?background-rgb]
  (if ?background-rgb
      (collect [role style (pairs (derived-styles ?background-rgb))
                &into (copy base-styles)]
        (values role style))
      base-styles))

(fn new [?background-rgb]
  {:background ?background-rgb
   :styles (styles ?background-rgb)
   :selected-row (.. "\27[1m" (or (colors.background-style ?background-rgb 0.08)
                                  ""))})

(local default-theme (new nil))

(fn ensure [theme]
  (or theme default-theme))

(fn style-for [theme role]
  (let [styles (. (ensure theme) :styles)]
    (. styles role)))

(fn line-tints? [theme]
  (if (and (style-for theme :line-added) (style-for theme :line-deleted))
      true
      false))

(fn color [theme role text]
  (ansi.apply-style (style-for theme role) text))

(fn tint [theme role text]
  (ansi.apply-block-style (style-for theme role) text))

(fn strip-backgrounds [line]
  (let [(out _) (line:gsub "\27%[4%d[;%d]*m" "")]
    out))

(fn selected-row [theme line width]
  (let [line (ansi.pad-right (strip-backgrounds line) width)
        style (. (ensure theme) :selected-row)]
    (ansi.apply-block-style style line)))

(fn highlight-matches [theme text query]
  (ansi.highlight-matches text query (style-for theme :search-match)
                          (style-for theme :search-match-end)))

{: color
 :default default-theme
 : highlight-matches
 : line-tints?
 : new
 : selected-row
 : style-for
 : tint}
