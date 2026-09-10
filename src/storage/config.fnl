(local fennel-command (require :platform.fennel))
(local sys (require :platform.core))

(fn path []
  (let [xdg (sys.getenv "XDG_CONFIG_HOME")
        home (sys.getenv "HOME")]
    (if (and xdg (> (length xdg) 0))
        (.. xdg "/gdiff/config.fnl")
        (.. (or home ".") "/.config/gdiff/config.fnl"))))

(fn load []
  (let [path (path)
        (ok result) (fennel-command.load-file path)]
    (if (= ok nil) {}
        ok (or result {})
        (error (.. "Could not load " path ": " result)))))

(fn editor-command [config]
  (or config.editor (sys.getenv "GDIFF_EDITOR") (sys.getenv "VISUAL")
      (sys.getenv "EDITOR") "vim"))

{: editor-command : load : path}
