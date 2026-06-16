(local fennel (require :fennel))
(local git (require :git))
(local preview (require :preview))
(local sys (require :sys))

(fn read-manifest [path]
  (let [source (sys.read-file path)]
    (when source
      (let [(ok result) (pcall fennel.eval source
                               {:filename path :allowedGlobals []})]
        (when ok
          result)))))

(fn output-path [dir index]
  (.. dir "/" index ".fnl"))

(fn write-output [dir index lines]
  (let [path (output-path dir index)
        tmp (.. path ".tmp")]
    (when (sys.write-file tmp (fennel.view lines))
      (os.execute (.. "mv " (sys.shell-quote tmp) " " (sys.shell-quote path)
                      " 2>/dev/null")))))

(fn warm [manifest-path dir start step]
  (let [manifest (read-manifest manifest-path)]
    (when manifest
      (let [state {:revision manifest.revision
                   :preview_cache {}
                   :preview_context (git.preview-context)}]
        (for [i start (length manifest.entries) step]
          (write-output dir i (preview.lines state (. manifest.entries i))))))))

(let [manifest-path (. arg 1)
      output-dir (. arg 2)
      start-index (tonumber (. arg 3))
      step (tonumber (. arg 4))]
  (warm manifest-path output-dir start-index step))
