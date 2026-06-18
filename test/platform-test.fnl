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

(fn test-file-exists-checks-plain-files []
  (let [path "/tmp/gdiff-platform-file-exists-test"]
    (sys.remove-file path)
    (faith.= false (sys.file-exists? path))
    (faith.is (sys.write-file path "x"))
    (faith.= true (sys.file-exists? path))
    (sys.remove-file path)
    (faith.= false (sys.file-exists? path))))

(fn test-dir-exists-checks-directories []
  (let [path "/tmp/gdiff-platform-dir-exists-test"]
    (sys.remove-dir path)
    (faith.= false (sys.dir-exists? path))
    (faith.is (sys.ensure-dir path))
    (faith.= true (sys.dir-exists? path))
    (sys.remove-dir path)
    (faith.= false (sys.dir-exists? path))))

{: test-background-shell-command-detaches-from-terminal
 : test-browser-command-quotes-url
 : test-dir-exists-checks-directories
 : test-editor-detached-command-does-not-use-terminal-stdin
 : test-file-exists-checks-plain-files}
