(local faith (require :faith))
(local moves (require :git.moves))

(fn entry [kind path]
  {: kind :status kind : path :reviewed false})

(local old-progress "class ProgressTracker
  PROGRESS_PATH = \"/tmp/progress.json\"

  def initialize(workflow_run)
    @workflow_run = workflow_run
  end

  def record_step(step_name)
    payload = {step: step_name, run: @workflow_run}
    File.write(PROGRESS_PATH, payload.to_json)
  end
end
")

(local new-progress "module Steps
  class ProgressTracker
    def record_step(step_name, workflow_run:)
      write_payload(step_name, workflow_run)
    end

    def write_payload(step_name, workflow_run)
      File.write(ENV.fetch(\"PROGRESS_PATH\"), {step_name:, workflow_run:}.to_json)
    end
  end
end
")

(fn test-annotate-marks-rewritten-move-with-same-name []
  (let [deleted (entry "D" "lib/acme/v2/progress.rb")
        added (entry "A" "lib/acme/v2/steps/progress.rb")
        modified (entry "M" "lib/app.rb")]
    (moves.annotate [deleted modified added]
                    {deleted old-progress added new-progress})
    (faith.= "lib/acme/v2/steps/progress.rb" deleted.moved_to)
    (faith.= "lib/acme/v2/progress.rb" added.moved_from)
    (faith.is (<= 0.35 deleted.moved_score))
    (faith.= deleted.moved_score added.moved_score)
    (faith.= nil modified.moved_to)
    (faith.= nil modified.moved_from)))

(fn test-annotate-pairs-renamed-file-on-strong-content-match []
  (let [deleted (entry "D" "lib/progress.rb")
        renamed (entry "A" "lib/steps/workflow_progress.rb")
        unrelated (entry "A" "lib/mailer.rb")]
    (moves.annotate [deleted renamed unrelated]
                    {deleted old-progress
                     renamed old-progress
                     unrelated "class Mailer\n  def deliver_notification\n  end\nend\n"})
    (faith.= "lib/steps/workflow_progress.rb" deleted.moved_to)
    (faith.= "lib/progress.rb" renamed.moved_from)
    (faith.= nil unrelated.moved_from)))

(fn test-annotate-skips-ambiguous-targets-without-name-match []
  (let [deleted (entry "D" "a/config.rb")
        first-twin (entry "A" "b/settings.rb")
        second-twin (entry "A" "c/options.rb")]
    (moves.annotate [deleted first-twin second-twin]
                    {deleted old-progress
                     first-twin old-progress
                     second-twin old-progress})
    (faith.= nil deleted.moved_to)
    (faith.= nil first-twin.moved_from)
    (faith.= nil second-twin.moved_from)))

(fn test-annotate-breaks-ambiguity-with-matching-basename []
  (let [deleted (entry "D" "a/config.rb")
        twin (entry "A" "b/settings.rb")
        same-name (entry "A" "c/config.rb")]
    (moves.annotate [deleted twin same-name]
                    {deleted old-progress
                     twin old-progress
                     same-name old-progress})
    (faith.= "c/config.rb" deleted.moved_to)
    (faith.= nil twin.moved_from)))

(fn test-annotate-pairs-each-entry-at-most-once []
  (let [best (entry "D" "a/x.rb")
        weaker (entry "D" "b/x.rb")
        added (entry "A" "c/x.rb")]
    (moves.annotate [best weaker added]
                    {best old-progress
                     weaker "class Unrelated\n  def other_thing\n  end\nend\n"
                     added old-progress})
    (faith.= "c/x.rb" best.moved_to)
    (faith.= nil weaker.moved_to)
    (faith.= "a/x.rb" added.moved_from)))

(fn test-annotate-prefers-rare-shared-lines-over-common-ones []
  (let [deleted (entry "D" "src/x.rb")
        rare-match (entry "A" "a/x.rb")
        common-match (entry "A" "b/x.rb")
        other-deleted (entry "D" "src2/y.rb")]
    (moves.annotate [deleted rare-match common-match other-deleted]
                    {deleted "rare_shared_marker_line\ncommon_everywhere_line\n"
                     rare-match "rare_shared_marker_line\nunique_added_one\n"
                     common-match "common_everywhere_line\nunique_added_two\n"
                     other-deleted "common_everywhere_line\nunique_deleted_two\n"})
    (faith.= "a/x.rb" deleted.moved_to)
    (faith.= "src/x.rb" rare-match.moved_from)
    (faith.= nil common-match.moved_from)))

(fn test-annotate-requires-matching-extension []
  (let [deleted (entry "D" "a/progress.rb")
        added (entry "A" "b/progress.md")]
    (moves.annotate [deleted added] {deleted old-progress added old-progress})
    (faith.= nil deleted.moved_to)))

(fn test-annotate-skips-binary-content []
  (let [deleted (entry "D" "a/blob.dat")
        added (entry "A" "b/blob.dat")
        binary (.. "some_shared_marker\n\0binary" (string.rep "x" 100))]
    (moves.annotate [deleted added] {deleted binary added binary})
    (faith.= nil deleted.moved_to)))

(fn test-annotate-skips-oversized-content []
  (let [deleted (entry "D" "a/huge.txt")
        added (entry "A" "b/huge.txt")
        huge (string.rep "shared_marker_line\n" 40000)]
    (moves.annotate [deleted added] {deleted huge added huge})
    (faith.= nil deleted.moved_to)))

(fn test-annotate-skips-entries-without-content []
  (let [deleted (entry "D" "a/progress.rb")
        added (entry "A" "b/progress.rb")]
    (moves.annotate [deleted added] {deleted old-progress})
    (faith.= nil deleted.moved_to)
    (faith.= nil added.moved_from)))

(fn test-candidates-requires-both-sides []
  (faith.= nil (moves.candidates [(entry "D" "a.rb") (entry "M" "b.rb")]))
  (faith.= nil (moves.candidates [(entry "A" "a.rb")])))

(fn test-candidates-caps-pair-count []
  (let [entries []]
    (for [i 1 21]
      (table.insert entries (entry "D" (.. "d" i ".rb"))))
    (for [i 1 20]
      (table.insert entries (entry "A" (.. "a" i ".rb"))))
    (faith.= nil (moves.candidates entries)))
  (let [cands (moves.candidates [(entry "D" "a.rb") (entry "A" "b.rb")])]
    (faith.= 1 (length cands.deleted))
    (faith.= 1 (length cands.added))))

(fn test-note-formats-move-annotations []
  (faith.= " (moved to lib/steps/progress.rb, 60%)"
           (moves.note {:moved_score 0.6 :moved_to "lib/steps/progress.rb"}))
  (faith.= " (moved from lib/progress.rb, 41%)"
           (moves.note {:moved_from "lib/progress.rb" :moved_score 0.41}))
  (faith.= "" (moves.note {:kind "D" :path "a.rb"})))

{: test-annotate-marks-rewritten-move-with-same-name
 : test-annotate-pairs-renamed-file-on-strong-content-match
 : test-annotate-skips-ambiguous-targets-without-name-match
 : test-annotate-breaks-ambiguity-with-matching-basename
 : test-annotate-pairs-each-entry-at-most-once
 : test-annotate-prefers-rare-shared-lines-over-common-ones
 : test-annotate-requires-matching-extension
 : test-annotate-skips-binary-content
 : test-annotate-skips-oversized-content
 : test-annotate-skips-entries-without-content
 : test-candidates-requires-both-sides
 : test-candidates-caps-pair-count
 : test-note-formats-move-annotations}
