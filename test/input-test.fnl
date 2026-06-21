(local faith (require :faith))
(local input (require :app.input))

(fn state [?search-active?]
  {:search {:active? (= ?search-active? true)}})

(fn test-navigation-keys-are-coalescible []
  (let [state (state)]
    (faith.= true (input.coalesce? state "j"))
    (faith.= true (input.coalesce? state "k"))
    (faith.= true (input.coalesce? state "G"))
    (faith.= true (input.coalesce? state "g"))))

(fn test-other-keys-are-not-coalescible []
  (let [state (state)]
    (faith.= nil (input.coalesce? state :enter))
    (faith.= nil (input.coalesce? state :up))
    (faith.= nil (input.coalesce? state " "))
    (faith.= nil (input.coalesce? state "o"))))

(fn test-search-input-is-never-coalescible []
  (let [state (state true)]
    (faith.= false (input.coalesce? state "j"))
    (faith.= false (input.coalesce? state "G"))))

{: test-navigation-keys-are-coalescible
 : test-other-keys-are-not-coalescible
 : test-search-input-is-never-coalescible}
