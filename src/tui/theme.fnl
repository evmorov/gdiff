(local ansi (require :tui.ansi))
(local colors (require :tui.colors))
(local txt (require :tui.text))

(local plain-styles {:muted "\27[2m"
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

(fn copy [styles]
  (collect [role style (pairs styles)]
    (values role style)))

(fn merge [base extra]
  (collect [role style (pairs extra) &into (copy base)]
    (values role style)))

;; One 256-color code per blame author slot. The unknown-background palette is
;; mid-tone; the others are brighter on a dark background and darker on a light
;; one.
(local blame-palettes
       {:unknown [110 143 175 108 173 140 73]
        :on-dark [117 186 218 114 216 183 80]
        :on-light [67 100 132 65 130 97 30]})

(fn blame-styles [palette]
  (collect [i code (ipairs palette)]
    (values (.. :blame- i) (.. "\27[38;5;" code "m"))))

(local base-styles (merge plain-styles (blame-styles blame-palettes.unknown)))

(local green {:r 0 :g 200 :b 0})
(local red {:r 255 :g 0 :b 0})
(local line-tint-amount 0.12)
(local emphasis-tint-amount 0.3)
(local search-background-amount 0.28)
(local keep-marker "\1")

(fn blame-palette-for [background-rgb]
  (if (< (colors.luminance background-rgb) 0.5)
      blame-palettes.on-dark
      blame-palettes.on-light))

(fn derived-styles [background-rgb search-background]
  (merge (blame-styles (blame-palette-for background-rgb))
         {:search-match (.. search-background "\27[1m")
          :search-match-end ansi.reset-style
          :line-added (colors.tint-style background-rgb green line-tint-amount)
          :line-deleted (colors.tint-style background-rgb red line-tint-amount)
          :emphasis-tint-added (colors.tint-style background-rgb green
                                                  emphasis-tint-amount)
          :emphasis-tint-deleted (colors.tint-style background-rgb red
                                                    emphasis-tint-amount)}))

(fn styles [?background-rgb ?search-background]
  (if ?background-rgb
      (merge base-styles (derived-styles ?background-rgb ?search-background))
      base-styles))

(fn new [?background-rgb]
  (let [search-background (and ?background-rgb
                               (colors.background-style ?background-rgb
                                                        search-background-amount))]
    {:background ?background-rgb
     :search-background search-background
     :styles (styles ?background-rgb search-background)
     :selected-row (.. "\27[1m" (or (colors.background-style ?background-rgb
                                                             0.08)
                                    ""))}))

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

(fn strip-backgrounds [line ?keep]
  "Drop background codes so the row paints evenly, except `?keep`, the search
match background, which must stay visible on the selected row."
  (let [protected (if ?keep
                      (pick-values 1
                                   (line:gsub (txt.pattern-quote ?keep)
                                              keep-marker))
                      line)
        stripped (pick-values 1 (protected:gsub "\27%[4%d[;%d]*m" ""))]
    (if ?keep
        (pick-values 1
                     (stripped:gsub keep-marker
                                    (pick-values 1 (?keep:gsub "%%" "%%%%"))))
        stripped)))

(fn selected-row [theme line width]
  (let [theme (ensure theme)
        line (ansi.pad-right (strip-backgrounds line theme.search-background)
                             width)]
    (ansi.apply-block-style theme.selected-row line)))

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
