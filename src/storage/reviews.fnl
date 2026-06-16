(local fennel (require :fennel))
(local sys (require :platform.core))

(fn state-dir []
  (let [xdg (os.getenv "XDG_STATE_HOME")
        home (os.getenv "HOME")]
    (if (and xdg (> (length xdg) 0))
        (.. xdg "/gdiff")
        (.. (or home ".") "/.local/state/gdiff"))))

(fn state-path []
  (.. (state-dir) "/reviews.fnl"))

(fn empty-store []
  {:version 1 :reviews {}})

(fn normalize-store [store]
  (if (= (type store) "table")
      (do
        (when (not (= (type store.reviews) "table"))
          (set store.reviews {}))
        (set store.version 1)
        store)
      (empty-store)))

(fn load-store []
  (let [path (state-path)
        source (sys.read-file path)]
    (if source
        (let [(ok result) (pcall fennel.eval source
                                 {:filename path :allowedGlobals []})]
          (if ok
              (normalize-store result)
              (empty-store)))
        (empty-store))))

(fn save-store [store]
  (and (sys.ensure-dir (state-dir))
       (sys.write-file (state-path) (fennel.view (normalize-store store)))))

(fn scope [root revision]
  (.. root "\31" revision))

(fn paths [entries]
  (collect [_ entry (ipairs entries)]
    (if entry.reviewed
        (values entry.path true))))

(fn marks [store scope]
  (or (. store.reviews scope) {}))

(fn empty? [t]
  (var result true)
  (each [_ _ (pairs t)]
    (set result false))
  result)

(fn persist [store scope entries]
  (let [reviewed (paths entries)]
    (if (empty? reviewed)
        (tset store.reviews scope nil)
        (tset store.reviews scope reviewed))
    (save-store store)))

(fn apply [entries reviewed]
  (each [_ entry (ipairs entries)]
    (when (. reviewed entry.path)
      (set entry.reviewed true)))
  entries)

{: apply : load-store : marks : paths : persist : scope : state-path}
