(local faith (require :faith))

(faith.run [:app-test
            :args-test
            :git-test
            :preview-test
            :preview_warm_test
            :reviews-test
            :sync-test
            :tui-test
            :update-test])
