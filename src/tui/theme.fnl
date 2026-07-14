(local ansi (require :tui.ansi))
(local colors (require :tui.colors))

(local base-styles {:muted "\27[2m"
                    :selected-marker "\27[1m"
                    :status-added "\27[32m"
                    :status-modified "\27[33m"
                    :status-deleted "\27[31m"
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

(fn styles [?background-rgb]
  (let [search-background (colors.background-style ?background-rgb 0.28)]
    (if search-background
        (doto (collect [role style (pairs base-styles)]
                (values role style))
          (tset :search-match (.. search-background "\27[1m"))
          (tset :search-match-end ansi.reset-style))
        base-styles)))

(fn new [?background-rgb]
  {:styles (styles ?background-rgb)
   :selected-row (.. "\27[1m" (or (colors.background-style ?background-rgb 0.08)
                                  ""))})

(local default-theme (new nil))

(fn ensure [theme]
  (or theme default-theme))

(fn style-for [theme role]
  (let [styles (. (ensure theme) :styles)]
    (. styles role)))

(fn color [theme role text]
  (ansi.apply-style (style-for theme role) text))

(fn selected-row [theme line width]
  (let [line (ansi.pad-right line width)
        style (. (ensure theme) :selected-row)]
    (ansi.apply-block-style style line)))

(fn highlight-matches [theme text query]
  (ansi.highlight-matches text query (style-for theme :search-match)
                          (style-for theme :search-match-end)))

{: color
 :default default-theme
 : highlight-matches
 : new
 : selected-row
 : style-for}
