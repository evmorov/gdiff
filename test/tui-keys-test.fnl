(local faith (require :faith))
(local ansi (require :tui.ansi))
(local keys (require :tui.keys))

(fn test-decode-maps-control-keys []
  (faith.= :tick (keys.decode {} nil))
  (faith.= :enter (keys.decode {} "\r"))
  (faith.= :enter (keys.decode {} "\n"))
  (faith.= :quit (keys.decode {} "\3")))

(fn test-decode-maps-escape-sequences []
  (faith.= :up (keys.decode {} ansi.esc "[" "A"))
  (faith.= :down (keys.decode {} ansi.esc "[" "B"))
  (faith.= :paste-start (keys.decode {} ansi.esc "[200~"))
  (faith.= :paste-end (keys.decode {} ansi.esc "[201~"))
  (faith.= :escape (keys.decode {} ansi.esc "[" "C")))

(fn test-decode-treats-escape-as-escape-during-search []
  (let [state {:search {:active? true}}]
    (faith.= :escape (keys.decode state ansi.esc "[" "A"))))

(fn test-decode-returns-printable-key []
  (faith.= "j" (keys.decode {} "j")))

{: test-decode-maps-control-keys
 : test-decode-maps-escape-sequences
 : test-decode-returns-printable-key
 : test-decode-treats-escape-as-escape-during-search}
