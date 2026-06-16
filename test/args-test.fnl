(local args (require :app.args))
(local faith (require :faith))

(fn test-parses-editor-and-revision []
  (let [(options revision err) (args.parse ["--editor" "nvim" "main...HEAD"])]
    (faith.= nil err)
    (faith.= "nvim" options.editor)
    (faith.= "main...HEAD" revision)))

(fn test-parses-inline-editor []
  (let [(options revision err) (args.parse ["--editor=code --wait" "HEAD"])]
    (faith.= nil err)
    (faith.= "code --wait" options.editor)
    (faith.= "HEAD" revision)))

(fn test-rejects-extra-revision []
  (let [(_options revision err) (args.parse ["main" "feature"])]
    (faith.= "main" revision)
    (faith.= "Unexpected extra argument: feature" err)))

(fn test-requires-editor-value []
  (let [(_options revision err) (args.parse ["--editor"])]
    (faith.= nil revision)
    (faith.= "--editor needs a value" err)))

{: test-parses-editor-and-revision
 : test-parses-inline-editor
 : test-rejects-extra-revision
 : test-requires-editor-value}
