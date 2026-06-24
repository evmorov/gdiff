(local fennel-command (require :platform.fennel))

(fn path []
  (let [xdg (os.getenv "XDG_CONFIG_HOME")
        home (os.getenv "HOME")]
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
  (or config.editor (os.getenv "GDIFF_EDITOR") (os.getenv "VISUAL")
      (os.getenv "EDITOR") "vim"))

{: editor-command : load : path}
