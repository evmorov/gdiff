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

(fn picker [revision
            entries
            config
            review-store
            review-scope
            src-dir
            diff-stats
            ?pr-url]
  (let [state (app-update.init revision entries review-store review-scope
                               src-dir diff-stats ?pr-url)]
    (app-update.start state)
    (tui.run {: state
              :view app-view.view
              :update #(app-update.handle-key $1 config $2)
              :coalesce? app-update.coalesce?})))

(fn exit-with-error [message]
  (io.stderr:write message "\n")
  (os.exit 1))

(fn merge-options [config options]
  (when options.editor
    (set config.editor options.editor))
  config)

(fn run [revision options src-dir ?pr-url]
  (let [revision (git.comparison-revision revision)
        config (merge-options (config-store.load) options)
        (entries err) (git.diff-entries revision)]
    (if err (exit-with-error err) (= (length entries) 0)
        (print "No changed files.")
        (let [review-store (reviews.load-store)
              scope (reviews.scope (git.repo-root) revision)
              (diff-stats _stats-err) (git.diff-stats revision)
              entries (reviews.apply entries (reviews.marks review-store scope))]
          (picker revision entries config review-store scope src-dir diff-stats
                  ?pr-url)))))

(fn run-pr [pr options src-dir]
  (io.stderr:write (.. "Resolving PR #" pr.number "...\n"))
  (let [(revision err) (git.resolve-pr-revision pr)]
    (if err
        (exit-with-error err)
        (run revision options src-dir pr.url))))

(fn main [argv src-dir]
  (let [(options revision err pr) (args.parse argv)]
    (if err (do
              (io.stderr:write err "\n")
              (args.usage)
              (os.exit 1)) pr (run-pr pr options src-dir) revision
        (run revision options src-dir)
        (let [(revision err) (git.default-revision)]
          (if err
              (do
                (io.stderr:write err "\n")
                (args.usage)
                (os.exit 1))
              (run revision options src-dir))))))

{: handle-key : main : new-state : view}
