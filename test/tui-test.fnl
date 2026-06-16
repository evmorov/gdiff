(local faith (require :faith))
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

{: test-empty-footer-is-nil : test-screen-builds-declarative-view-tree}
