(local ansi (require :tui.ansi))
(local colors (require :tui.colors))

(local base-styles {:muted "\27[2m"
                    :selected-marker "\27[1m"
                    :status-added "\27[32m"
                    :status-modified "\27[33m"
                    :status-deleted "\27[31m"
                    :status-renamed "\27[36m"
                    :status-copied "\27[35m"
                    :notice "\27[90m"
                    :warning "\27[31m"
                    :search-match "\27[1;4m"
                    :search-match-end "\27[22;24m"})

(fn styles [?background-rgb ?foreground-rgb]
  (let [search-background (colors.background-style ?background-rgb 0.28)
        folder-foreground (colors.foreground-style ?foreground-rgb
                                                   ?background-rgb 0.25)]
    (if search-background
        (doto (collect [role style (pairs base-styles)]
                (values role style))
          (tset :folder folder-foreground)
          (tset :search-match (.. search-background "\27[1m"))
          (tset :search-match-end ansi.reset-style))
        (doto (collect [role style (pairs base-styles)]
                (values role style))
          (tset :folder folder-foreground)))))

(fn new [?background-rgb ?foreground-rgb]
  {:styles (styles ?background-rgb ?foreground-rgb)
   :selected-row (colors.background-style ?background-rgb 0.08)})

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
