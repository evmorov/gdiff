(local fennel (require :fennel))
(local preview-key (require :preview_key))
(local sys (require :sys))

(fn make-dir []
  (let [path (sys.temp-path)]
    (sys.remove-file path)
    (when (sys.ensure-dir path)
      path)))

(fn output-path [dir index]
  (.. dir "/" index ".fnl"))

(fn manifest-path [dir]
  (.. dir "/manifest.fnl"))

(fn worker-command [src-dir manifest dir]
  (.. "fennel --add-fennel-path " (sys.shell-quote (.. src-dir "/?.fnl")) " "
      (sys.shell-quote (.. src-dir "/preview_worker.fnl")) " "
      (sys.shell-quote manifest) " " (sys.shell-quote dir)))

(fn new-state []
  {:dir nil :next-index 1 :count 0 :key-index {} :index-key {}})

(fn cleanup [state]
  (when state.dir
    (sys.remove-dir state.dir))
  (set state.dir nil)
  (set state.next-index 1)
  (set state.count 0)
  (set state.key-index {})
  (set state.index-key {}))

(fn write-manifest [path revision entries]
  (sys.write-file path (fennel.view {:revision revision :entries entries})))

(fn index-entries [revision entries]
  (let [indexes {}
        keys {}]
    (each [i entry (ipairs entries)]
      (let [entry-key (preview-key.for-entry revision entry)]
        (tset indexes entry-key i)
        (tset keys i entry-key)))
    (values indexes keys)))

(fn start [state src-dir revision entries]
  (cleanup state)
  (let [dir (make-dir)]
    (when dir
      (let [manifest (manifest-path dir)]
        (when (write-manifest manifest revision entries)
          (let [(key-index index-key) (index-entries revision entries)]
            (set state.key-index key-index)
            (set state.index-key index-key))
          (set state.dir dir)
          (set state.next-index 1)
          (set state.count (length entries))
          (sys.background-command (worker-command src-dir manifest dir)))))))

(fn read-lines [path]
  (let [source (sys.read-file path)]
    (when source
      (let [(ok result) (pcall fennel.eval source
                               {:filename path :allowedGlobals []})]
        (when ok
          result)))))

(fn update [state cache]
  (when state.dir
    (var keep-going? true)
    (while (and keep-going? (<= state.next-index state.count))
      (let [path (output-path state.dir state.next-index)
            lines (read-lines path)]
        (if lines
            (do
              (let [key (. state.index-key state.next-index)]
                (when key
                  (tset cache key lines)))
              (sys.remove-file path)
              (set state.next-index (+ state.next-index 1)))
            (set keep-going? false)))))
  (when (and state.dir (> state.next-index state.count))
    (cleanup state)))

{: new-state : start : update}
