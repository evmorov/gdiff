(local faith (require :faith))
(local ansi (require :tui.ansi))
(local keys (require :tui.keys))

(fn test-decode_maps_control_keys []
  (faith.= :tick (keys.decode {} nil))
  (faith.= :enter (keys.decode {} "\r"))
  (faith.= :enter (keys.decode {} "\n"))
  (faith.= :quit (keys.decode {} "\3")))

(fn test-decode_maps_escape_sequences []
  (faith.= :up (keys.decode {} ansi.esc "[" "A"))
  (faith.= :down (keys.decode {} ansi.esc "[" "B"))
  (faith.= :paste-start (keys.decode {} ansi.esc "[200~"))
  (faith.= :paste-end (keys.decode {} ansi.esc "[201~"))
  (faith.= :escape (keys.decode {} ansi.esc "[" "C")))

(fn test-decode_treats_escape_as_escape_during_search []
  (let [state {:search {:active? true}}]
    (faith.= :escape (keys.decode state ansi.esc "[" "A"))))

(fn test-decode_returns_printable_key []
  (faith.= "j" (keys.decode {} "j")))

{: test-decode_maps_control_keys
 : test-decode_maps_escape_sequences
 : test-decode_returns_printable_key
 : test-decode_treats_escape_as_escape_during_search}
