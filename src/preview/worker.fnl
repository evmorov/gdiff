(local preview (require :preview.core))
(local plan (require :preview.warm-plan))
(local sys (require :platform.core))
(local worker-state (require :preview.worker-state))

(fn read-manifest [path]
  (let [(ok result) (sys.read-data-file path)]
    (when ok
      result)))

(fn write-output [dir index data]
  (sys.write-data-file (plan.output-path dir index) data))

(fn warm [manifest-path dir start step]
  (let [manifest (read-manifest manifest-path)]
    (when manifest
      (let [state (worker-state.from-settings manifest.settings)]
        (var canceled? false)
        (for [i start (length manifest.entries) step]
          (if canceled?
              nil
              (sys.file-exists? manifest-path)
              (write-output dir i
                            (preview.warm-entry state (. manifest.entries i)))
              (set canceled? true)))))))

(let [manifest-path (. arg 1)
      output-dir (. arg 2)
      start-index (tonumber (. arg 3))
      step (tonumber (. arg 4))]
  (warm manifest-path output-dir start-index step))
