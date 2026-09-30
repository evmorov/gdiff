(local faith (require :faith))
(local plan (require :preview.focus-plan))

(local wanted {:id "k\0blame"
               :key "k"
               :kind :entry
               :target {:path "a.rb"}
               :generation 2})

(fn test-request-carries-what-to-compute-and-how []
  (faith.= {:seq 7
            :id "k\0blame"
            :generation 2
            :key "k"
            :kind :entry
            :target {:path "a.rb"}
            :settings {:revision "HEAD"}}
           (plan.request 7 wanted {:revision "HEAD"})))

(fn test-needs-request-once-per-id-and-generation []
  (faith.= true (plan.needs-request? nil wanted))
  (faith.= false (plan.needs-request? {:id "k\0blame" :generation 2} wanted))
  (faith.= true (plan.needs-request? {:id "k" :generation 2} wanted))
  (faith.= true (plan.needs-request? {:id "k\0blame" :generation 1} wanted)))

(fn test-claimable-waits-one-poll-for-a-request []
  (faith.= false (plan.claimable? nil {:seq 3}))
  (faith.= false (plan.claimable? 2 {:seq 3}))
  (faith.= true (plan.claimable? 3 {:seq 3}))
  (faith.= nil (plan.claimable? 3 nil)))

(fn test-accept-drops-other-generations []
  (faith.= true (plan.accept? {:key "k" :generation 2} 2))
  (faith.= false (plan.accept? {:key "k" :generation 1} 2))
  (faith.= false (plan.accept? {:generation 2} 2))
  (faith.= false (plan.accept? "junk" 2)))

(fn test-response-tags-data-with-the-request []
  (faith.= {:key "k" :generation 2 :kind :entry :lines ["x"]}
           (plan.response wanted {:lines ["x"]})))

(fn test-paths-live-in-the-server-dir []
  (faith.= "d/request.lua" (plan.request-path "d"))
  (faith.= "d/claimed.lua" (plan.claimed-path "d"))
  (faith.= "d/out-3.lua" (plan.response-path "d" 3))
  (faith.= "d/ready" (plan.ready-path "d"))
  (faith.= "d/alive" (plan.alive-path "d")))

{: test-accept-drops-other-generations
 : test-claimable-waits-one-poll-for-a-request
 : test-needs-request-once-per-id-and-generation
 : test-paths-live-in-the-server-dir
 : test-request-carries-what-to-compute-and-how
 : test-response-tags-data-with-the-request}
