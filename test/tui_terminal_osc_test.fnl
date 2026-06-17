(local faith (require :faith))
(local ansi (require :tui.ansi))
(local osc (require :tui.terminal_osc))

(fn reader [chars]
  (var index 0)
  (fn []
    (set index (+ index 1))
    (. chars index)))

(fn test-terminator_detects_bel_and_st []
  (faith.= true (osc.terminator? "abc\7" "\7"))
  (faith.= true (osc.terminator? (.. "abc" ansi.esc "\\") "\\"))
  (faith.= false (osc.terminator? "abc" "c")))

(fn test-read_response_stops_at_bel []
  (faith.= "abc\7" (osc.read-response (reader ["a" "b" "c" "\7" "x"]) 10)))

(fn test-read_response_stops_at_string_terminator []
  (faith.= (.. "abc" ansi.esc "\\")
           (osc.read-response (reader ["a" "b" "c" ansi.esc "\\" "x"]) 10)))

(fn test-read_response_stops_at_limit []
  (faith.= "ab" (osc.read-response (reader ["a" "b" "c"]) 2)))

{: test-read_response_stops_at_bel
 : test-read_response_stops_at_limit
 : test-read_response_stops_at_string_terminator
 : test-terminator_detects_bel_and_st}
