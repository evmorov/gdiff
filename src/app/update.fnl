(local actions (require :app.actions))
(local command-runner (require :app.command_runner))
(local commands (require :app.commands))
(local input (require :app.input))
(local preview-warm (require :preview.warm))
(local search (require :app.search))
(local app-state (require :app.state))
(local sync (require :git.sync))

(fn update-remote-sync [state]
  (let [running? state.sync.running?]
    (sync.update state.sync)
    (when (and running? (not state.sync.running?)
               (not (sync.warning state.sync)))
      (let [sync-notice (sync.notice state.sync)]
        (if sync-notice (set state.notice sync-notice)
            state.show_sync_notice? (set state.notice "Remote in sync"))))
    (when (and running? (not state.sync.running?))
      (set state.show_sync_notice? false)
      (set state.force_next_draw? true))))

(fn update [state config msg]
  (set state.skip_next_draw? false)
  (let [msg-type (and (= (type msg) :table) msg.type)
        command (case msg-type
                  :quit (do
                          (preview-warm.cleanup state.preview_warm)
                          (set state.quit? true)
                          commands.none)
                  :pending-key (do
                                 (set state.pending-key msg.pending-key)
                                 commands.none)
                  :search-input (do
                                  (search.handle-input state msg.key)
                                  commands.none)
                  :review-persist-failed (do
                                           (set state.notice
                                                "Could not save reviewed marks")
                                           commands.none)
                  :copy-path-finished (do
                                        (actions.set-notice state
                                                            (if msg.ok?
                                                                "Copied"
                                                                "Copy failed")
                                                            msg.path)
                                        commands.none)
                  :open-pr-finished (do
                                      (set state.notice
                                           (if msg.ok?
                                               (.. "Opened PR: " msg.url)
                                               (or msg.error "No linked PR")))
                                      commands.none)
                  :refresh-loaded (actions.apply-refresh state msg.entries
                                                         msg.reviewed
                                                         msg.diff_stats)
                  _ (do
                      (set state.pending-key msg.pending-key)
                      (command-runner.command-or-none (actions.handle state
                                                                      config
                                                                      msg-type))))]
    (values state command)))

(fn run-command [state config command]
  (command-runner.run state config update command))

(fn init [revision entries review-store review-scope src-dir ?diff-stats]
  (app-state.init revision entries review-store review-scope src-dir
                  ?diff-stats))

(fn handle-key [state config raw-key]
  (set state.force_next_draw? false)
  (update-remote-sync state)
  (when (= raw-key :tick)
    (preview-warm.update state.preview_warm state.preview_cache))
  (let [(_ command) (update state config (input.read-msg state raw-key))]
    (run-command state config command))
  (not state.quit?))

(fn start-command [state]
  (actions.cache-selected-preview state)
  (commands.batch (commands.warm-preview-cache) (commands.sync-start)))

(fn start [state]
  (run-command state {} (start-command state)))

{:cache-selected-preview actions.cache-selected-preview
 : handle-key
 : init
 :new-state init
 :read-msg input.read-msg
 : run-command
 : start
 : start-command
 : update}
