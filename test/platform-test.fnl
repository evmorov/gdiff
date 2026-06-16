(local faith (require :faith))
(local browser (require :platform.browser))
(local editor (require :platform.editor))
(local sys (require :platform.core))

(fn test-background-shell-command-detaches-from-terminal []
  (faith.= "( printf hi ) </dev/null >/dev/null 2>&1 &"
           (sys.background-shell-command "printf hi")))

(fn test-browser-command-quotes-url []
  (faith.= "open 'https://example.com/pull/1?x=y'"
           (browser.command "https://example.com/pull/1?x=y" "open")))

(fn test-editor-detached-command-does-not-use-terminal-stdin []
  (faith.= "( code 'a.rb' ) </dev/null >/dev/null 2>&1 &"
           (sys.background-shell-command (editor.command "code" "a.rb"))))

{: test-background-shell-command-detaches-from-terminal
 : test-browser-command-quotes-url
 : test-editor-detached-command-does-not-use-terminal-stdin}
