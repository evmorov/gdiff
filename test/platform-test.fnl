(local faith (require :faith))
(local browser (require :platform.browser))
(local sys (require :platform.core))

(fn test-background-shell-command-detaches-from-terminal []
  (faith.= "( printf hi ) </dev/null >/dev/null 2>&1 &"
           (sys.background-shell-command "printf hi")))

(fn test-browser-command-quotes-url []
  (faith.= "open 'https://example.com/pull/1?x=y'"
           (browser.command "https://example.com/pull/1?x=y" "open")))

{: test-background-shell-command-detaches-from-terminal
 : test-browser-command-quotes-url}
