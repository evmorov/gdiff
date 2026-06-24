(local fennel (require :fennel))
(local sys (require :platform.core))

(fn eval-source [source path]
  (pcall fennel.eval source {:filename path :allowedGlobals []}))

(fn load-file [path]
  (let [source (sys.read-file path)]
    (when source
      (eval-source source path))))

(fn runtime-path [src-dir]
  (.. src-dir "/?.fnl"))

(fn macro-path [src-dir]
  (.. src-dir "/?.fnlm;" src-dir "/?.fnl"))

(fn command [src-dir script args]
  (let [parts ["fennel"
               "--add-fennel-path"
               (sys.shell-quote (runtime-path src-dir))
               "--add-macro-path"
               (sys.shell-quote (macro-path src-dir))
               (sys.shell-quote (.. src-dir "/" script))]]
    (each [_ arg (ipairs (or args []))]
      (table.insert parts (sys.shell-quote arg)))
    (table.concat parts " ")))

{: command : eval-source : load-file : macro-path : runtime-path}
