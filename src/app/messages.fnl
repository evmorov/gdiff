(fn build [message-type ?fields]
  (let [message {:type message-type}]
    (each [key value (pairs (or ?fields {}))]
      (tset message key value))
    message))

(fn quit []
  (build :quit))

(fn pending-key [pending-key]
  (build :pending-key {: pending-key}))

(fn action [message-type pending-key]
  (build message-type {: pending-key}))

(fn search-input [key]
  (build :search-input {: key}))

(fn review-persist-failed []
  (build :review-persist-failed))

(fn copy-path-finished [path ok?]
  (build :copy-path-finished {: path : ok?}))

(fn open-pr-finished [?url ?error ok?]
  (build :open-pr-finished {:url ?url :error ?error : ok?}))

(fn open-target-finished [target path ok?]
  (build :open-target-finished {: target : path : ok?}))

(fn refresh-loaded [entries reviewed diff-stats]
  (build :refresh-loaded {: entries : reviewed :diff_stats diff-stats}))

{: action
 : build
 : copy-path-finished
 : open-pr-finished
 : open-target-finished
 : pending-key
 : quit
 : refresh-loaded
 : review-persist-failed
 : search-input}
