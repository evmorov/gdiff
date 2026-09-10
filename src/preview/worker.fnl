(local fennel (require :fennel))
(local fennel-command (require :platform.fennel))
(local preview (require :preview.core))
(local plan (require :preview.warm-plan))
(local sys (require :platform.core))
(local theme (require :tui.theme))

(fn read-manifest [path]
  (let [(ok result) (fennel-command.load-file path)]
    (when ok
      result)))

(fn write-output [dir index lines]
  (let [path (plan.output-path dir index)
        tmp (.. path ".tmp")]
    (when (sys.write-file tmp (fennel.view lines))
      (sys.rename tmp path))))

(fn warm [manifest-path dir start step]
  (let [manifest (read-manifest manifest-path)]
    (when manifest
      (let [highlight (or manifest.highlight {})
            state {:revision manifest.revision
                   :revision_old_label manifest.old-label
                   :revision_new_label manifest.new-label
                   :show_blame? (and manifest.blame? true)
                   :highlight? (and highlight.on? true)
                   :highlight_available? (and highlight.on? true)
                   :bat_theme highlight.bat-theme
                   :theme (theme.new highlight.background)
                   :preview_cache {}
                   :split_cache {}}]
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
