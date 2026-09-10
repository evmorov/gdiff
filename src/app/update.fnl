(local actions (require :app.actions))
(local command-runner (require :app.command-runner))
(local commands (require :app.commands))
(local input (require :app.input))
(local messages (require :app.messages))
(local notice (require :app.notice))
(local folder-preview (require :preview.folder))
(local preview (require :preview.core))
(local preview-warm (require :preview.warm))
(local search (require :app.pane-search))
(local selection (require :app.selection))
(local app-state (require :app.state))
(local pr-refresh (require :git.pr-refresh))
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
  (set state.quit? true)
  (commands.warm-cleanup))

(fn handle-pending-key [state _config msg]
  (set state.pending_key msg.pending-key)
  commands.none)

(fn handle-ignore [state _config _msg]
  (set state.skip_next_draw? true)
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

(fn handle-yank-finished [state _config msg]
  (set state.notice (notice.yank-finished msg.ok? msg.count))
  commands.none)

(fn handle-yank-fenced-finished [state _config msg]
  (set state.notice (notice.yank-fenced-finished msg.ok? msg.path msg.count))
  commands.none)

(fn handle-open-pr-finished [state _config msg]
  (set state.notice (notice.open-pr-finished msg.ok? msg.url msg.error))
  commands.none)

(fn handle-open-commit-finished [state _config msg]
  (set state.notice (notice.open-commit-finished msg.ok? msg.url msg.error))
  commands.none)

(fn handle-open-target-finished [state _config msg]
  (set state.notice (notice.open-target-finished msg.target msg.path msg.ok?))
  commands.none)

(fn handle-open-base-finished [state _config msg]
  (set state.notice (notice.open-base-finished msg.ok? msg.ref msg.path
                                               msg.error))
  commands.none)

(fn handle-refresh-loaded [state _config msg]
  (actions.apply-refresh state msg.entries msg.reviewed msg.diff_stats
                         msg.revision))

(fn handle-folder-listings-loaded [state config msg]
  (folder-preview.store-records state msg.records)
  (command-runner.command-or-none (actions.handle state config msg.then)))

(fn handle-pr-refresh-finished [state _config msg]
  (set state.force_next_draw? true)
  (if msg.info
      (commands.pr-refresh-resolve msg.info)
      (do
        (set state.notice (notice.pr-refresh-failed msg.error))
        commands.none)))

(fn handle-pr-refresh-resolved [state _config msg]
  (if msg.revision
      (do
        (set state.notice (notice.pr-refreshed))
        (commands.refresh msg.revision))
      (do
        (set state.notice (notice.pr-refresh-failed msg.error))
        commands.none)))

(local message-handlers
       {:copy-path-finished handle-copy-path-finished
        :folder-listings-loaded handle-folder-listings-loaded
        :ignore handle-ignore
        :open-base-finished handle-open-base-finished
        :open-commit-finished handle-open-commit-finished
        :open-pr-finished handle-open-pr-finished
        :open-target-finished handle-open-target-finished
        :pending-key handle-pending-key
        :pr-refresh-finished handle-pr-refresh-finished
        :pr-refresh-resolved handle-pr-refresh-resolved
        :quit handle-quit
        :refresh-loaded handle-refresh-loaded
        :review-persist-failed handle-review-persist-failed
        :search-input handle-search-input
        :yank-finished handle-yank-finished
        :yank-fenced-finished handle-yank-fenced-finished})

(fn handle-action [state config msg msg-type]
  (set state.pending_key msg.pending-key)
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

(fn dispatch-now [state config msg]
  (let [(_ command) (update state config msg)]
    (run-command state config command)))

(fn poll-pr-refresh [state]
  "Poll the background PR refresh and return a message once it has finished."
  (let [running? state.pr_refresh.running?]
    (pr-refresh.update state.pr_refresh)
    (when (and running? (not state.pr_refresh.running?))
      (messages.pr-refresh-finished state.pr_refresh.info
                                    state.pr_refresh.error))))

(fn init [revision
          entries
          review-store
          review-scope
          src-dir
          ?diff-stats
          ?pr-url
          ?highlight]
  (app-state.init revision entries review-store review-scope src-dir
                  ?diff-stats ?pr-url ?highlight))

(fn update-warm-cache [state]
  (when (preview.prepare-entry state (selection.selected-entry state))
    (set state.force_next_draw? true))
  (preview-warm.update state.preview_warm (preview.warm-caches state)))

(fn handle-key [state config raw-key]
  (set state.force_next_draw? false)
  (update-remote-sync state)
  (case (poll-pr-refresh state)
    msg (dispatch-now state config msg))
  (when (= raw-key :tick)
    (update-warm-cache state))
  (dispatch-now state config (input.read-msg state raw-key))
  (when (= raw-key :tick)
    (set state.skip_next_draw? true))
  (not state.quit?))

(fn start-command [state]
  (actions.cache-selected-preview state)
  (commands.batch (commands.warm-preview-cache) (commands.sync-start)))

(fn start [state]
  (run-command state {} (start-command state)))

{:cache-selected-preview actions.cache-selected-preview
 :coalesce? input.coalesce?
 : handle-key
 : init
 :new-state init
 :read-msg input.read-msg
 : run-command
 : start
 : start-command
 : update}
