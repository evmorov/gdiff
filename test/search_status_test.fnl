(local faith (require :faith))
(local status (require :app.search_status))

(fn search-state [active? query index matches]
  {: active? : query : index : matches})

(fn test-active_status_shows_prompt_text []
  (faith.= "/api │ 2 matches │ enter finish │ esc clear"
           (status.active "api" 2))
  (faith.= "/api │ 1 match │ enter finish │ esc clear"
           (status.active "api" 1)))

(fn test-inactive_status_shows_result_navigation []
  (faith.= "Search: 2/5 api │ n/N next/prev │ q clear"
           (status.inactive "api" 2 5))
  (faith.= "No matches for 'missing'" (status.inactive "missing" 0 0))
  (faith.= nil (status.inactive "" 0 0)))

(fn test-notice_uses_active_or_inactive_status []
  (faith.= "/a │ 1 match │ enter finish │ esc clear"
           (status.notice (search-state true "a" 0 [{:entry 1}])))
  (faith.= "Search: 1/1 a │ n/N next/prev │ q clear"
           (status.notice (search-state false "a" 1 [{:entry 1}]))))

(fn test-prompt_only_exists_while_active []
  (faith.= "/a │ 0 matches │ enter finish │ esc clear"
           (status.prompt (search-state true "a" 0 [])))
  (faith.= nil (status.prompt (search-state false "a" 1 [{:entry 1}]))))

{: test-active_status_shows_prompt_text
 : test-inactive_status_shows_result_navigation
 : test-notice_uses_active_or_inactive_status
 : test-prompt_only_exists_while_active}
