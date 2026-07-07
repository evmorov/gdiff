(local faith (require :faith))
(local messages (require :app.messages))

(fn test-action-message-keeps-pending-key []
  (faith.= {:type :top :pending-key nil} (messages.action :top nil))
  (faith.= {:type :toggle-tree :pending-key "g"}
           (messages.action :toggle-tree "g")))

(fn test-command-result-messages-are-plain-data []
  (faith.= {:type :copy-path-finished :path "src/a.rb" :ok? true}
           (messages.copy-path-finished "src/a.rb" true))
  (faith.= {:type :open-pr-finished :url "https://example.com" :ok? true}
           (messages.open-pr-finished "https://example.com" nil true))
  (faith.= {:type :open-pr-finished :error "No linked PR" :ok? false}
           (messages.open-pr-finished nil "No linked PR" false))
  (faith.= {:type :open-commit-finished :url "https://example.com" :ok? true}
           (messages.open-commit-finished "https://example.com" nil true))
  (faith.= {:type :open-commit-finished
            :error "No commit for this line"
            :ok? false}
           (messages.open-commit-finished nil "No commit for this line" false)))

(fn test-open-target-finished-message-is-plain-data []
  (faith.= {:type :open-target-finished :target :folder :path "src" :ok? false}
           (messages.open-target-finished :folder "src" false)))

{: test-action-message-keeps-pending-key
 : test-command-result-messages-are-plain-data
 : test-open-target-finished-message-is-plain-data}
