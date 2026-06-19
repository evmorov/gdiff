(local faith (require :faith))
(local ansi (require :tui.ansi))
(local osc (require :tui.terminal-osc))

(fn reader [chars]
  (var index 0)
  (fn []
    (set index (+ index 1))
    (. chars index)))

(fn test-terminator-detects-bel-and-st []
  (faith.= true (osc.terminator? "abc\7" "\7"))
  (faith.= true (osc.terminator? (.. "abc" ansi.esc "\\") "\\"))
  (faith.= false (osc.terminator? "abc" "c")))

(fn test-read-response-stops-at-bel []
  (faith.= "abc\7" (osc.read-response (reader ["a" "b" "c" "\7" "x"]) 10)))

(fn test-read-response-stops-at-string-terminator []
  (faith.= (.. "abc" ansi.esc "\\")
           (osc.read-response (reader ["a" "b" "c" ansi.esc "\\" "x"]) 10)))

(fn test-read-response-stops-at-limit []
  (faith.= "ab" (osc.read-response (reader ["a" "b" "c"]) 2)))

{: test-read-response-stops-at-bel
 : test-read-response-stops-at-limit
 : test-read-response-stops-at-string-terminator
 : test-terminator-detects-bel-and-st}
