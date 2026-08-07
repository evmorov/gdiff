(local args (require :app.args))
(local commands (require :git.commands))
(local faith (require :faith))
(local t (require :test-helper))

(fn test-parses-working-keyword []
  (let [(_options revision err) (args.parse ["working"])]
    (faith.= nil err)
    (faith.= commands.working-revision revision)))

(fn test-parses-working-shorthand []
  (let [(_options revision err) (args.parse ["w"])]
    (faith.= nil err)
    (faith.= commands.working-revision revision)))

(fn test-parses-editor-and-revision []
  (let [(options revision err) (args.parse ["--editor" "nvim" "main" "HEAD"])]
    (faith.= nil err)
    (faith.= "nvim" options.editor)
    (faith.= "main...HEAD" revision)))

(fn test-parses-inline-editor []
  (let [(options revision err) (args.parse ["--editor=code --wait" "HEAD"])]
    (faith.= nil err)
    (faith.= "code --wait" options.editor)
    (faith.= "HEAD" revision)))

(fn test-no-revision-defers-to-default-revision-lookup []
  (let [(_options revision err) (args.parse [])]
    (faith.= nil err)
    (faith.= nil revision)))

(fn test-parses-two-revisions-as-triple-dot-range []
  (let [(_options revision err) (args.parse ["main" "feature"])]
    (faith.= nil err)
    (faith.= "main...feature" revision)))

(fn test-parses-two-existing-files-as-file-comparison []
  (let [exists? #(or (= $ "../old copy.txt") (= $ "new.txt"))
        (_options revision err) (args.parse ["../old copy.txt" "new.txt"]
                                            exists?)]
    (faith.= nil err)
    (faith.= (commands.files-revision "../old copy.txt" "new.txt") revision)))

(fn test-parses-two-existing-folders-as-file-comparison []
  (t.reset-workdir)
  (t.mkdir "old dir")
  (t.mkdir "new dir")
  (let [(_options revision err) (args.parse ["old dir" "new dir"])]
    (faith.= nil err)
    (faith.= (commands.files-revision "old dir" "new dir") revision)))

(fn test-keeps-revision-range-when-only-one-arg-is-a-file []
  (let [exists? #(= $ "main")
        (_options revision err) (args.parse ["main" "feature"] exists?)]
    (faith.= nil err)
    (faith.= "main...feature" revision)))

(fn test-parses-explicit-triple-dot-range []
  (let [(_options revision err) (args.parse ["main...HEAD"])]
    (faith.= nil err)
    (faith.= "main...HEAD" revision)))

(fn test-rejects-extra-revision []
  (let [(_options revision err) (args.parse ["main" "feature" "extra"])]
    (faith.= nil revision)
    (faith.= "Unexpected extra argument: extra" err)))

(fn test-rejects-two-dot-range []
  (let [(_options revision err) (args.parse ["main..feature"])]
    (faith.= "main..feature" revision)
    (faith.= "Two-dot ranges are not supported; use ..." err)))

(fn test-parses-pr-url []
  (let [(_options revision err pr) (args.parse ["https://github.com/acme/widgets/pull/17080"])]
    (faith.= nil err)
    (faith.= nil revision)
    (faith.= {:owner "acme"
              :repo "widgets"
              :number "17080"
              :url "https://github.com/acme/widgets/pull/17080"}
             pr)))

(fn test-parses-pr-url-with-trailing-path []
  (let [(_options _revision err pr) (args.parse ["https://github.com/acme/widgets/pull/17080/changes"])]
    (faith.= nil err)
    (faith.= "https://github.com/acme/widgets/pull/17080" pr.url)
    (faith.= "17080" pr.number)))

(fn test-rejects-pr-url-with-extra-revision []
  (let [(_options revision err pr) (args.parse ["main"
                                                "https://github.com/acme/widgets/pull/17080"])]
    (faith.= nil revision)
    (faith.= nil pr)
    (faith.= "A PR URL cannot be combined with other revisions" err)))

(fn test-treats-malformed-pr-url-as-revision []
  (let [(_options revision err pr) (args.parse ["https://github.com/acme/widgets/pull/17080abc"])]
    (faith.= nil err)
    (faith.= nil pr)
    (faith.= "https://github.com/acme/widgets/pull/17080abc" revision)))

(fn test-requires-editor-value []
  (let [(_options revision err) (args.parse ["--editor"])]
    (faith.= nil revision)
    (faith.= "--editor needs a value" err)))

{: test-parses-editor-and-revision
 : test-parses-working-keyword
 : test-parses-working-shorthand
 : test-parses-explicit-triple-dot-range
 : test-parses-inline-editor
 : test-keeps-revision-range-when-only-one-arg-is-a-file
 : test-no-revision-defers-to-default-revision-lookup
 : test-parses-pr-url
 : test-parses-two-existing-files-as-file-comparison
 : test-parses-two-existing-folders-as-file-comparison
 : test-parses-pr-url-with-trailing-path
 : test-parses-two-revisions-as-triple-dot-range
 : test-rejects-extra-revision
 : test-rejects-pr-url-with-extra-revision
 : test-rejects-two-dot-range
 : test-requires-editor-value
 : test-treats-malformed-pr-url-as-revision}
