(local fennel (require :fennel))

(fn dirname [path]
  (or (path:match "^(.*)/[^/]+$") "."))

(local src-dir (dirname (. arg 0)))

(set fennel.path (.. src-dir "/?.fnl;" fennel.path))
(set fennel.macro-path (.. src-dir "/?.fnlm;" src-dir "/?.fnl;"
                           fennel.macro-path))

(local app (require :app.core))

(app.main arg src-dir)
