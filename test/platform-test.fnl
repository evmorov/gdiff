(local faith (require :faith))
(local browser (require :platform.browser))
(local clipboard (require :platform.clipboard))
(local editor (require :platform.editor))
(local sys (require :platform.core))

(fn test-background-shell-command-detaches-from-terminal []
  (faith.= "( printf hi ) </dev/null >/dev/null 2>&1 &"
           (sys.background-shell-command "printf hi")))

(fn test-browser-command-quotes-url []
  (faith.= "open 'https://example.com/pull/1?x=y'"
           (browser.command "https://example.com/pull/1?x=y" "open")))

(fn available-from [programs]
  (fn [program]
    (accumulate [found false _ p (ipairs programs) &until found]
      (= p program))))

(fn test-clipboard-prefers-pbcopy-on-macos []
  (faith.= "pbcopy"
           (clipboard.choose-command {:os "Darwin"}
                                     (available-from ["xclip" "pbcopy"]))))

(fn test-clipboard-uses-wl-copy-on-wayland []
  (faith.= "wl-copy"
           (clipboard.choose-command {:os "Linux" :WAYLAND_DISPLAY "wayland-0"}
                                     (available-from ["wl-copy" "xclip"]))))

(fn test-clipboard-falls-back-to-xclip-when-wl-copy-is-missing []
  (faith.= "xclip -selection clipboard"
           (clipboard.choose-command {:os "Linux" :WAYLAND_DISPLAY "wayland-0"}
                                     (available-from ["xclip" "xsel"]))))

(fn test-clipboard-ignores-wl-copy-outside-wayland []
  (faith.= "xsel --clipboard --input"
           (clipboard.choose-command {:os "Linux" :WAYLAND_DISPLAY ""}
                                     (available-from ["wl-copy" "xsel"]))))

(fn test-clipboard-has-no-command-when-nothing-is-installed []
  (faith.= nil (clipboard.choose-command {:os "Linux"} (available-from []))))

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
 : test-clipboard-prefers-pbcopy-on-macos
 : test-clipboard-uses-wl-copy-on-wayland
 : test-clipboard-falls-back-to-xclip-when-wl-copy-is-missing
 : test-clipboard-ignores-wl-copy-outside-wayland
 : test-clipboard-has-no-command-when-nothing-is-installed
 : test-dir-exists-checks-directories
 : test-editor-detached-command-does-not-use-terminal-stdin
 : test-file-exists-checks-plain-files}
