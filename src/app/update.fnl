(local actions (require :app.actions))
(local command-runner (require :app.command_runner))
(local commands (require :app.commands))
(local input (require :app.input))
(local notice (require :app.notice))
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
            state.show_sync_notice? (set state.notice (notice.remote-in-sync)))))
    (when (and running? (not state.sync.running?))
      (set state.show_sync_notice? false)
      (set state.force_next_draw? true))))

(fn handle-quit [state _config _msg]
  (preview-warm.cleanup state.preview_warm)
  (set state.quit? true)
  commands.none)

(fn handle-pending-key [state _config msg]
  (set state.pending-key msg.pending-key)
  commands.none)

(fn handle-search-input [state _config msg]
  (search.handle-input state msg.key)
  commands.none)

(fn handle-review-persist-failed [state _config _msg]
  (set state.notice (notice.review-persist-failed))
  commands.none)

(fn handle-copy-path-finished [state _config msg]
  (set state.notice (notice.copy-finished msg.ok? msg.path))
  commands.none)

(fn handle-open-pr-finished [state _config msg]
  (set state.notice (notice.open-pr-finished msg.ok? msg.url msg.error))
  commands.none)

(fn handle-open-target-finished [state _config msg]
  (set state.notice (notice.open-target-finished msg.target msg.path msg.ok?))
  commands.none)

(fn handle-refresh-loaded [state _config msg]
  (actions.apply-refresh state msg.entries msg.reviewed msg.diff_stats))

(local message-handlers
       {:copy-path-finished handle-copy-path-finished
        :open-pr-finished handle-open-pr-finished
        :open-target-finished handle-open-target-finished
        :pending-key handle-pending-key
        :quit handle-quit
        :refresh-loaded handle-refresh-loaded
        :review-persist-failed handle-review-persist-failed
        :search-input handle-search-input})

(fn handle-action [state config msg msg-type]
  (set state.pending-key msg.pending-key)
  (command-runner.command-or-none (actions.handle state config msg-type)))

(fn command-for-message [state config msg]
  (let [msg-type (and (= (type msg) :table) msg.type)
        handler (. message-handlers msg-type)]
    (if handler
        (handler state config msg)
        (handle-action state config msg msg-type))))

(fn update [state config msg]
  (set state.skip_next_draw? false)
  (values state (command-for-message state config msg)))

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
 : update
 :command-for-message command-for-message}
