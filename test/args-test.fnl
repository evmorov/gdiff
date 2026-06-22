(local args (require :app.args))
(local commands (require :git.commands))
(local faith (require :faith))

(fn test-parses-staged-keyword []
  (let [(_options revision err) (args.parse ["staged"])]
    (faith.= nil err)
    (faith.= commands.staged-revision revision)))

(fn test-parses-staged-shorthand []
  (let [(_options revision err) (args.parse ["s"])]
    (faith.= nil err)
    (faith.= commands.staged-revision revision)))

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

(fn test-requires-editor-value []
  (let [(_options revision err) (args.parse ["--editor"])]
    (faith.= nil revision)
    (faith.= "--editor needs a value" err)))

{: test-parses-editor-and-revision
 : test-parses-staged-keyword
 : test-parses-staged-shorthand
 : test-parses-explicit-triple-dot-range
 : test-parses-inline-editor
 : test-no-revision-defers-to-default-revision-lookup
 : test-parses-two-revisions-as-triple-dot-range
 : test-rejects-extra-revision
 : test-rejects-two-dot-range
 : test-requires-editor-value}
