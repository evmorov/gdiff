(local fennel (require :fennel))

(fn shell-quote [s]
  (let [escaped (string.gsub (tostring s) "'" "'\\''")]
    (.. "'" escaped "'")))

(fn read-command [cmd]
  (let [f (io.popen cmd "r")]
    (if f
        (let [output (f:read "*a")
              (ok kind code) (f:close)]
          (values output ok kind code))
        (values "" false "open" 1))))

(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn read-file [path]
  (let [f (io.open path "r")]
    (when f
      (let [contents (f:read "*a")]
        (f:close)
        contents))))

(fn write-file [path contents]
  (let [f (io.open path "w")]
    (if f
        (do
          (f:write contents)
          (f:close)
          true)
        false)))

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
        source (read-file path)]
    (if source
        (let [(ok result) (pcall fennel.eval source
                                 {:filename path :allowedGlobals []})]
          (if ok
              (normalize-store result)
              (empty-store)))
        (empty-store))))

(fn ensure-dir [path]
  (let [(ok _kind _code) (os.execute (.. "mkdir -p " (shell-quote path)
                                         " 2>/dev/null"))]
    ok))

(fn save-store [store]
  (and (ensure-dir (state-dir))
       (write-file (state-path) (fennel.view (normalize-store store)))))

(fn repo-root []
  (let [(output ok _kind _code) (read-command "git rev-parse --show-toplevel 2>/dev/null")]
    (if ok
        (trim output)
        (or (os.getenv "PWD") "."))))

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

{: apply
 : load-store
 : marks
 : paths
 : persist
 : repo-root
 : scope
 : state-path}
