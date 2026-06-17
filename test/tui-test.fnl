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
    (faith.= 6 (tui.context-body-rows ctx))))

(fn test-layout-names_screen_regions []
  (let [regions (tui.layout.screen 10 80)]
    (faith.= {:row 1 :col 1 :rows 1 :cols 80} regions.header)
    (faith.= {:row 2 :col 1 :rows 1 :cols 80} regions.header-rule)
    (faith.= {:row 3 :col 1 :rows 6 :cols 80} regions.body)
    (faith.= {:row 9 :col 1 :rows 1 :cols 80} regions.bottom-rule)
    (faith.= {:row 10 :col 1 :rows 1 :cols 80} regions.footer)
    (faith.= 4 (tui.layout.row regions.body 2))))

(fn test-components-are-exposed-for-extension []
  (faith.= :table (type tui.components))
  (faith.= :table (type tui.renderer))
  (faith.= :table (type tui.surface))
  (faith.= :table (type tui.layout))
  (faith.= :function (type tui.components.split.draw))
  (faith.= :function (type tui.components.list.draw))
  (faith.= :function (type tui.components.lines.draw))
  (faith.= :function (type tui.components.scrollbar.draw))
  (faith.= :function (type tui.components.screen.draw))
  (faith.= tui.components.screen (tui.renderer.component-for {:type :screen}))
  (faith.= :function (type tui.surface.write-at)))

(fn test-renderer-dispatches_registered_components []
  (let [calls []
        component {:draw (fn [_ctx node]
                           (table.insert calls node.value))}
        node {:type :test-component :value "drawn"}]
    (tui.renderer.register node.type component)
    (tui.renderer.draw (tui.context 5 20) node)
    (faith.= ["drawn"] calls)))

(fn test-header-rule-connects_top_bar_separators []
  (let [rule (tui.components.header.rule-line "a │ b │ c" 9)]
    (faith.= "──┴───┴──" rule)))

(fn test-header-rule-connects_body_divider []
  (let [rule (tui.components.header.rule-line "abcdefghi" 9 5)]
    (faith.= "────┬────" rule)))

(fn test-header-rule-crosses_top_bar_separator_and_body_divider []
  (let [rule (tui.components.header.rule-line "a │ b" 5 3)]
    (faith.= "──┼──" rule)))

(fn test-bottom-rule-connects_body_divider []
  (let [rule (tui.components.chrome.bottom-rule 9 5)]
    (faith.= "────┴────" rule)))

(fn test-bottom-rule-connects_footer_right_separator []
  (let [rule (tui.components.chrome.bottom-rule 9 nil 7)]
    (faith.= "──────┬──" rule)))

(fn test-bottom-rule-crosses_body_divider_and_footer_separator []
  (let [rule (tui.components.chrome.bottom-rule 9 5 5)]
    (faith.= "────┼────" rule)))

(fn test-bottom-rule-connects_all_footer_right_separators []
  (let [footer-cols (tui.components.footer.rule-cols 30 nil
                                                     "65 files │ 12/65 reviewed")
        rule (tui.components.chrome.bottom-rule 30 nil footer-cols)]
    (faith.= "───┬──────────┬───────────────"
             rule)))

(fn test-bottom-rule-connects_left_footer_separators []
  (let [footer-cols (tui.components.footer.rule-cols 20 "a │ b │ c" nil)]
    (faith.= true (. footer-cols 3))
    (faith.= true (. footer-cols 7))))

(fn test-footer-right-col_includes_leading_separator []
  (faith.= 8 (tui.components.footer.right-col 20 "11 chars ok")))

(fn test-footer-text-styles_separators_as_muted []
  (let [ctx (tui.context 10 80)
        node (tui.footer :prompt "Search │ next")
        styled (tui.components.footer.styled-text ctx node node.text)]
    (faith.= "Search │ next" (ansi.strip-ansi styled))
    (when (ansi.color?)
      (faith.is (styled:find "\27[2m│" 1 true)))))

(fn test-visible-length-counts_utf8_glyph_as_one_cell []
  (faith.= 1 (ansi.visible-length "│"))
  (faith.= 5 (ansi.visible-length "a │ b")))

(fn test-truncate_preserves_whole_utf8_glyphs []
  (faith.= "a │..." (ansi.truncate "a │ b c" 6)))

(fn test-split-component-calculates_widths []
  (let [(left right divider) (tui.components.split.widths 101 0.4)]
    (faith.= 40 left)
    (faith.= 60 right)
    (faith.= 41 divider)))

(fn test-scrollbar_only_visible_for_overflow []
  (faith.is (tui.components.scrollbar.visible? {:offset 0 :total 10 :visible 5}
                                               5))
  (faith.= nil (tui.components.scrollbar.visible? {:offset 0
                                                   :total 5
                                                   :visible 5}
                                                  5)))

(fn test-scrollbar_thumb_tracks_offset []
  (let [scroll {:offset 5 :total 10 :visible 5}
        (start finish) (tui.components.scrollbar.thumb-range scroll 5)]
    (faith.= 3 start)
    (faith.= 5 finish)
    (faith.= nil (tui.components.scrollbar.marker scroll 5 2))
    (faith.= "█" (tui.components.scrollbar.marker scroll 5 3))))

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
      (faith.is (row:find "\27[1m" 1 true))
      (faith.= nil (row:find "48;5;" 1 true))
      (faith.is (row:find "\27[48;2;" 1 true))
      (faith.is (row:find "\27[0m\27[1m\27[48;2;" 1 true)))))

(fn test-selected-row-does-not-guess-without-background []
  (let [t (theme.new nil)
        row (theme.selected-row t (.. (theme.color t :selected-marker "> ")
                                      "a.rb")
                                8)]
    (faith.= "> a.rb  " (ansi.strip-ansi row))
    (when (row:find ansi.esc 1 true)
      (faith.is (row:find "\27[1m" 1 true)))
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
 : test-bottom-rule-connects_footer_right_separator
 : test-bottom-rule-connects_all_footer_right_separators
 : test-bottom-rule-connects_body_divider
 : test-bottom-rule-connects_left_footer_separators
 : test-bottom-rule-crosses_body_divider_and_footer_separator
 : test-components-are-exposed-for-extension
 : test-footer-right-col_includes_leading_separator
 : test-footer-text-styles_separators_as_muted
 : test-header-rule-connects_body_divider
 : test-header-rule-connects_top_bar_separators
 : test-header-rule-crosses_top_bar_separator_and_body_divider
 : test-layout-names_screen_regions
 : test-parses-terminal-background-response
 : test-render-context-carries-terminal-shape
 : test-renderer-dispatches_registered_components
 : test-screen-builds-declarative-view-tree
 : test-split-component-calculates_widths
 : test-scrollbar_only_visible_for_overflow
 : test-scrollbar_thumb_tracks_offset
 : test-search-match-does-not-guess-background
 : test-search-match-uses-derived-background
 : test-selected-row-does-not-guess-without-background
 : test-selected-row-uses-derived-background
 : test-truncate_preserves_whole_utf8_glyphs
 : test-visible-length-counts_utf8_glyph_as_one_cell}
