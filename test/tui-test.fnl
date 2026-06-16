(local faith (require :faith))
(local ansi (require :tui.ansi))
(local colors (require :tui.colors))
(local theme (require :tui.theme))
(local tui (require :tui.core))

(fn test-screen-builds-declarative-view-tree []
  (let [row (tui.row "a.rb" true)
        left (tui.list [row])
        right (tui.lines ["diff"])
        footer (tui.footer :notice "Copied")
        screen (tui.screen "header" (tui.split left right 0.45) footer)]
    (faith.= :screen screen.type)
    (faith.= "header" screen.header)
    (faith.= :split screen.body.type)
    (faith.= 0.45 screen.body.ratio)
    (faith.= row (. screen.body.left.rows 1))
    (faith.= "diff" (. screen.body.right.lines 1))
    (faith.= :notice screen.footer.type)
    (faith.= "Copied" screen.footer.text)))

(fn test-empty-footer-is-nil []
  (faith.= nil (tui.footer :notice nil)))

(fn test-render-context-carries-terminal-shape []
  (let [ctx (tui.context 10 80)]
    (faith.= 10 ctx.rows)
    (faith.= 80 ctx.cols)
    (faith.= 7 (tui.context-body-rows ctx))))

(fn test-parses-terminal-background-response []
  (faith.= {:r 0 :g 17 :b 255}
           (colors.parse-background-response "\27]11;rgb:0000/1111/ffff\7")))

(fn test-selected-row-uses-derived-background []
  (let [t (theme.new {:r 16 :g 24 :b 32})
        row (theme.selected-row t (.. (theme.color t :selected-marker "> ")
                                      "a.rb")
                                8)]
    (faith.= "> a.rb  " (ansi.strip-ansi row))
    (when (row:find ansi.esc 1 true)
      (faith.= nil (row:find "48;5;" 1 true))
      (faith.is (row:find "\27[48;2;" 1 true))
      (faith.is (row:find "\27[0m\27[48;2;" 1 true)))))

(fn test-selected-row-does-not-guess-without-background []
  (let [t (theme.new nil)
        row (theme.selected-row t (.. (theme.color t :selected-marker "> ")
                                      "a.rb")
                                8)]
    (faith.= "> a.rb  " (ansi.strip-ansi row))
    (faith.= nil (row:find "48;" 1 true))
    (faith.= nil (row:find "\27[2;7m" 1 true))))

(fn test-search-match-uses-derived-background []
  (let [t (theme.new {:r 16 :g 24 :b 32})
        style (theme.style-for t :search-match)
        text (theme.highlight-matches t "abc" "b")]
    (faith.= "abc" (ansi.strip-ansi text))
    (faith.= nil (style:find "48;5;" 1 true))
    (faith.is (style:find "\27[48;2;" 1 true))))

(fn test-search-match-does-not-guess-background []
  (let [t (theme.new nil)
        style (theme.style-for t :search-match)
        text (theme.highlight-matches t "abc" "b")]
    (faith.= "abc" (ansi.strip-ansi text))
    (faith.= nil (style:find "48;" 1 true))))

{: test-empty-footer-is-nil
 : test-parses-terminal-background-response
 : test-render-context-carries-terminal-shape
 : test-screen-builds-declarative-view-tree
 : test-search-match-does-not-guess-background
 : test-search-match-uses-derived-background
 : test-selected-row-does-not-guess-without-background
 : test-selected-row-uses-derived-background}
