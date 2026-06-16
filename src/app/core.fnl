(local args (require :app.args))
(local config-store (require :storage.config))
(local git (require :git.core))
(local reviews (require :storage.reviews))
(local tui (require :tui.core))
(local app-update (require :app.update))
(local app-view (require :app.view))

(local handle-key app-update.handle-key)
(local new-state app-update.init)
(local view app-view.view)

(fn picker [revision entries config review-store review-scope src-dir]
  (let [state (app-update.init revision entries review-store review-scope
                               src-dir)]
    (app-update.start state)
    (tui.run {:state state
              :view app-view.view
              :update #(app-update.handle-key $1 config $2)})))

(fn exit-with-error [message]
  (io.stderr:write message "\n")
  (os.exit 1))

(fn merge-options [config options]
  (when options.editor
    (set config.editor options.editor))
  config)

(fn run [revision options src-dir]
  (let [revision (git.comparison-revision revision)
        config (merge-options (config-store.load) options)
        (entries err) (git.diff-entries revision)]
    (if err (exit-with-error err) (= (length entries) 0)
        (print "No changed files.")
        (let [review-store (reviews.load-store)
              scope (reviews.scope (git.repo-root) revision)
              entries (reviews.apply entries (reviews.marks review-store scope))]
          (picker revision entries config review-store scope src-dir)))))

(fn main [argv src-dir]
  (let [(options revision err) (args.parse argv)]
    (if err (do
              (io.stderr:write err "\n")
              (args.usage)
              (os.exit 1)) revision (run revision options src-dir)
        (let [(revision err) (git.default-revision)]
          (if err
              (do
                (io.stderr:write err "\n")
                (args.usage)
                (os.exit 1))
              (run revision options src-dir))))))

{:finish-background-sync-if-complete app-update.finish-background-sync-if-complete
 :handle-key handle-key
 :main main
 :new-state new-state
 :start-background-sync app-update.start-background-sync
 :update app-update.update
 :view view}
