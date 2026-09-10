(local ansi (require :tui.ansi))
(local file-preview (require :preview.file))
(local sys (require :platform.core))

(local default-theme "ansi")

(fn available? []
  (and (ansi.color?) (sys.command-exists? "bat") true))

(fn flags [path ?last-line theme]
  (.. "--color=always --style=plain --paging=never --wrap=never --tabs=0 "
      "--theme=" (sys.shell-quote (or theme default-theme)) " --file-name "
      (sys.shell-quote path) (if ?last-line
                                (.. " --line-range "
                                    (sys.shell-quote (.. ":" ?last-line)))
                                "")))

(fn command [source path ?last-line ?theme]
  (let [bat (.. "bat " (flags path ?last-line ?theme))]
    (if source.file
        (.. bat " -- " (sys.shell-quote source.file) " 2>/dev/null")
        (.. source.command " | " bat " 2>/dev/null"))))

(fn highlight-lines [source path ?last-line ?theme]
  (let [(output ok) (sys.read-command (command source path ?last-line ?theme))]
    (when (and ok output (< 0 (length output)))
      (file-preview.split-lines output))))

{: available? : command :default-theme default-theme : highlight-lines}
