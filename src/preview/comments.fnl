(local code-stats (require :git.code-stats))
(local str (require :util.string))

(fn comment-line? [?path ?text]
  (and ?path ?text (code-stats.comment-line? ?path (str.trim ?text)) true))

{: comment-line?}
