(local fennel (require :fennel))
(local fennel-command (require :platform.fennel))
(local git (require :git.core))
(local preview (require :preview.core))
(local plan (require :preview.warm-plan))
(local sys (require :platform.core))

(fn read-manifest [path]
  (let [source (sys.read-file path)]
    (when source
      (let [(ok result) (fennel-command.eval-source source path)]
        (when ok
          result)))))

(fn write-output [dir index lines]
  (let [path (plan.output-path dir index)
        tmp (.. path ".tmp")]
    (when (sys.write-file tmp (fennel.view lines))
      (sys.rename tmp path))))

(fn warm [manifest-path dir start step]
  (let [manifest (read-manifest manifest-path)]
    (when manifest
      (let [state {:revision manifest.revision
                   :preview_cache {}
                   :preview_context (git.preview-context)}]
        (var canceled? false)
        (for [i start (length manifest.entries) step]
          (if canceled?
              nil
              (sys.file-exists? manifest-path)
              (write-output dir i (preview.lines state (. manifest.entries i)))
              (set canceled? true)))))))

(let [manifest-path (. arg 1)
      output-dir (. arg 2)
      start-index (tonumber (. arg 3))
      step (tonumber (. arg 4))]
  (warm manifest-path output-dir start-index step))
