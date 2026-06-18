(local faith (require :faith))
(local messages (require :app.messages))

(fn test-action_message_keeps_pending_key []
  (faith.= {:type :top :pending-key nil} (messages.action :top nil))
  (faith.= {:type :toggle-tree :pending-key "g"}
           (messages.action :toggle-tree "g")))

(fn test-command_result_messages_are_plain_data []
  (faith.= {:type :copy-path-finished :path "src/a.rb" :ok? true}
           (messages.copy-path-finished "src/a.rb" true))
  (faith.= {:type :open-pr-finished :url "https://example.com" :ok? true}
           (messages.open-pr-finished "https://example.com" nil true))
  (faith.= {:type :open-pr-finished :error "No linked PR" :ok? false}
           (messages.open-pr-finished nil "No linked PR" false)))

(fn test-open_target_finished_message_is_plain_data []
  (faith.= {:type :open-target-finished :target :folder :path "src" :ok? false}
           (messages.open-target-finished :folder "src" false)))

{: test-action_message_keeps_pending_key
 : test-command_result_messages_are_plain_data
 : test-open_target_finished_message_is_plain_data}
