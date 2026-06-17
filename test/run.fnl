(local faith (require :faith))

(faith.run [:app-test
            :args-test
            :git-test
            :git_parse_test
            :platform-test
            :review-test
            :search_match_test
            :search_nav_test
            :search_status_test
            :preview-test
            :preview_warm_test
            :preview_warm_plan_test
            :preview_workers_test
            :reviews-test
            :sync-test
            :tree-test
            :tui_chrome_layout_test
            :tui_footer_layout_test
            :tui_footer_text_test
            :tui_keys_test
            :tui-test
            :tui_text_highlight_test
            :tui_text_test
            :tui_text_window_test
            :tui_terminal_osc_test
            :tui_terminal_probe_test
            :update-test
            :util_math_test])
