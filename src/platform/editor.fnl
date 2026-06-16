(local config-store (require :storage.config))
(local sys (require :platform.core))
(local tui (require :tui.core))

(fn command [editor path]
  (if (= (type editor) "table")
      (let [parts []]
        (each [_ part (ipairs editor)]
          (table.insert parts (sys.shell-quote part)))
        (table.insert parts (sys.shell-quote path))
        (table.concat parts " "))
      (.. editor " " (sys.shell-quote path))))

(fn program [editor]
  (let [program (if (= (type editor) "table")
                    (. editor 1)
                    (string.match (tostring editor) "^%s*(%S+)"))]
    (or (and program (program:match "([^/]+)$")) "")))

(fn gui? [editor]
  (let [program (program editor)]
    (or (= program "idea") (= program "code") (= program "cursor")
        (= program "subl") (= program "mate") (= program "open"))))

(fn detached? [config editor]
  (if (not (= config.detached nil))
      config.detached
      (gui? editor)))

(fn run-detached [cmd]
  (os.execute (.. cmd " >/dev/null 2>&1 &")))

(fn run [config entry stty-state]
  (let [editor (config-store.editor-command config)
        cmd (command editor entry.path)]
    (if (detached? config editor)
        (run-detached cmd)
        (tui.suspend stty-state #(os.execute cmd)))))

{: command : run}
