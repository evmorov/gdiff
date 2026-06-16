(local actions (require :actions))
(local args (require :args))
(local config-store (require :config))
(local git (require :git))
(local reviews (require :reviews))
(local tui (require :tui))
(local app-view (require :view))

(fn picker [revision entries config review-store review-scope src-dir]
  (let [state (actions.new-state revision entries review-store review-scope
                                 src-dir)]
    (actions.start state)
    (tui.run-loop state app-view.view #(actions.handle-key $1 config $2))))

(fn exit-with-error [message]
  (io.stderr:write message "\n")
  (os.exit 1))

(fn merge-options [config options]
  (when options.editor
    (set config.editor options.editor))
  config)

(fn run [revision options src-dir]
  (let [config (merge-options (config-store.load) options)
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

{:handle-key actions.handle-key
 :main main
 :new-state actions.new-state
 :view app-view.view}
