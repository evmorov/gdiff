(local faith (require :faith))
(local engine (require :app.search-engine))

(fn test-label-query-keeps-plain-query []
  (faith.= "app" (engine.label-query "app.fnl" "app")))

(fn test-label-query-keeps-path-when-present-in-text []
  (faith.= "src/app" (engine.label-query "src/app/" "src/app"))
  (faith.= "src/app/view.fnl"
           (engine.label-query "src/app/view.fnl" "src/app/view.fnl")))

(fn test-label-query-falls-back-to-trailing-segment-for-basename []
  (faith.= "view.fnl" (engine.label-query "view.fnl" "src/app/view.fnl"))
  (faith.= "vie" (engine.label-query "view.fnl" "src/app/vie")))

(fn test-label-query-handles-folder-path-with-trailing-slash []
  (faith.= "app" (engine.label-query "app/" "src/app/"))
  (faith.= "src/app" (engine.label-query "src/app/" "src/app/")))

{: test-label-query-keeps-plain-query
 : test-label-query-keeps-path-when-present-in-text
 : test-label-query-falls-back-to-trailing-segment-for-basename
 : test-label-query-handles-folder-path-with-trailing-slash}
