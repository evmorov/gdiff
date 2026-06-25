(local faith (require :faith))
(local app (require :app.core))
(local left-view (require :app.view.left))
(local split (require :tui.components.split))

(fn entry [status path]
  {: status :kind (status:sub 1 1) : path :reviewed false})

(fn state [entries]
  (let [state (app.new-state "HEAD" entries {:version 1 :reviews {}} "scope"
                             "src")]
    (set state.sync.next_at (+ (os.time) 999))
    state))

(fn test-auto-split-caps-at-forty-percent []
  (let [s (state [(entry "M"
                         "a_very_long_file_name_that_easily_exceeds_forty.rb")])]
    (app.view s 10 80)
    (faith.almost= 0.4 s.split_ratio 0.0001)))

(fn test-auto-split-shrinks-for-short-names []
  (let [s (state [(entry "M" "a.rb")])]
    (app.view s 10 80)
    (faith.is (< s.split_ratio 0.4))
    (faith.is (<= 0.1 s.split_ratio))))

(fn test-auto-split-leaves-gap-before-divider []
  (let [s (state [(entry "M" "a.rb")])]
    (app.view s 10 80)
    (let [content (left-view.content-width s)
          (left-cols) (split.widths 80 s.split_ratio)]
      (faith.is (> left-cols content)))))

(fn test-auto-split-floors-at-ten-percent []
  (let [s (state [(entry "M" "a.rb")])]
    (app.view s 10 4000)
    (faith.almost= 0.1 s.split_ratio 0.0001)))

(fn test-auto-split-only-adjusts-once []
  (let [s (state [(entry "M" "a.rb")])]
    (app.view s 10 80)
    (set s.split_ratio 0.4)
    (app.view s 10 80)
    (faith.almost= 0.4 s.split_ratio 0.0001)))

{: test-auto-split-caps-at-forty-percent
 : test-auto-split-shrinks-for-short-names
 : test-auto-split-leaves-gap-before-divider
 : test-auto-split-floors-at-ten-percent
 : test-auto-split-only-adjusts-once}
