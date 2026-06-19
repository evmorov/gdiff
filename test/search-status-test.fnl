(local faith (require :faith))
(local status (require :app.search-status))

(fn search-state [active? query index matches]
  {: active? : query : index : matches})

(fn test-active-status-shows-prompt-text []
  (faith.= "/api │ 2 matches │ enter finish │ esc clear"
           (status.active "api" 2))
  (faith.= "/api │ 1 match │ enter finish │ esc clear"
           (status.active "api" 1)))

(fn test-inactive-status-shows-result-navigation []
  (faith.= "Search: 2/5 api │ n/N next/prev │ q clear"
           (status.inactive "api" 2 5))
  (faith.= "No matches for 'missing'" (status.inactive "missing" 0 0))
  (faith.= nil (status.inactive "" 0 0)))

(fn test-notice-uses-active-or-inactive-status []
  (faith.= "/a │ 1 match │ enter finish │ esc clear"
           (status.notice (search-state true "a" 0 [{:entry 1}])))
  (faith.= "Search: 1/1 a │ n/N next/prev │ q clear"
           (status.notice (search-state false "a" 1 [{:entry 1}]))))

(fn test-prompt-only-exists-while-active []
  (faith.= "/a │ 0 matches │ enter finish │ esc clear"
           (status.prompt (search-state true "a" 0 [])))
  (faith.= nil (status.prompt (search-state false "a" 1 [{:entry 1}]))))

{: test-active-status-shows-prompt-text
 : test-inactive-status-shows-result-navigation
 : test-notice-uses-active-or-inactive-status
 : test-prompt-only-exists-while-active}
