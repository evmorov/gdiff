(local faith (require :faith))
(local word-diff (require :preview.word-diff))

(fn highlights [s ranges]
  (icollect [_ r (ipairs ranges)] (s:sub r.from (- r.to 1))))

(fn test-spans-isolate-the-changed-word []
  (let [old "foo bar baz"
        new "foo qux baz"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= ["bar"] (highlights old o))
    (faith.= ["qux"] (highlights new n))))

(fn test-spans-mark-only-the-added-tail []
  (let [old "alpha beta"
        new "alpha beta gamma"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= [] (highlights old o))
    (faith.= [" gamma"] (highlights new n))))

(fn test-spans-mark-only-the-removed-head []
  (let [old "drop keep tail"
        new "keep tail"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= ["drop "] (highlights old o))
    (faith.= [] (highlights new n))))

(fn test-spans-split-into-multiple-ranges-around-shared-words []
  (let [old "aaa bbb ccc ddd"
        new "aaa xxx ccc yyy"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= ["bbb" "ddd"] (highlights old o))
    (faith.= ["xxx" "yyy"] (highlights new n))))

(fn test-spans-anchor-the-leftmost-shared-word []
  (let [old "class Configuration"
        new "class Configuration < Epoxy::Configuration::Base"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= [] (highlights old o))
    (faith.= [" < Epoxy::Configuration::Base"] (highlights new n))))

(fn test-spans-highlight-only-the-extra-leading-space-when-deindented []
  (let [old "      it \"x\" do"
        new "    it \"x\" do"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= ["  "] (highlights old o))
    (faith.= [] (highlights new n))))

(fn test-spans-highlight-only-the-extra-leading-space-when-indented []
  (let [old "  foo"
        new "      foo"
        {:old o :new n} (word-diff.spans old new)]
    (faith.= [] (highlights old o))
    (faith.= ["    "] (highlights new n))))

(fn test-spans-empty-when-lines-match []
  (let [{:old o :new n} (word-diff.spans "same" "same")]
    (faith.= [] (highlights "same" o))
    (faith.= [] (highlights "same" n))))

(fn matched [pairs]
  (icollect [_ p (ipairs pairs)]
    (when (and p.old p.new) [p.old p.new])))

(fn test-align-pairs-equal-length-blocks-by-position []
  (faith.= [[1 1] [2 2]]
           (matched (word-diff.align ["one two three" "alpha beta gamma"]
                                     ["one TWO three" "alpha BETA gamma"]))))

(fn test-align-matches-the-similar-line-in-an-unbalanced-block []
  (faith.= [[1 1]]
           (matched (word-diff.align ["    class Configuration"
                                      "      attr_reader :socket_path"]
                                     ["    class Configuration < Base"
                                      "      config_name :metrics"
                                      "      # comment"]))))

(fn test-align-pairs-by-similarity-regardless-of-position []
  (faith.= [[3 1]]
           (matched (word-diff.align ["totally different"
                                      "another unrelated"
                                      "keep aaa tail"]
                                     ["keep bbb tail"]))))

(fn test-align-keeps-pairings-monotonic []
  (faith.= [[1 2]]
           (matched (word-diff.align ["apple red" "banana yellow"]
                                     ["banana YELLOW" "apple RED"]))))

(fn test-align-leaves-too-different-lines-unmatched []
  (faith.= []
           (matched (word-diff.align ["the quick brown fox"]
                                     ["a slow green turtle swims"]))))

(fn test-line-distance-counts-only-word-content []
  (faith.= 0 (word-diff.line-distance "foo bar" "foo bar"))
  (faith.= 0 (word-diff.line-distance "foo  bar" "foo\tbar()"))
  (faith.= 0.5 (word-diff.line-distance "foo bar" "foo baz")))

(fn test-line-distance-ignores-a-shared-prefix-when-the-rest-differs []
  (faith.is (> (word-diff.line-distance "Epoxy::Metrics.instance_variable_set(:@configuration, nil)"
                                        "Epoxy::Metrics.reset_configuration!")
               0.6))
  (faith.is (< (word-diff.line-distance "expect(config.enabled).to be(true)"
                                        "expect(described_class.new.enabled).to be(true)")
               0.6)))

(fn test-align-skips-pairs-that-only-share-a-prefix []
  (faith.= []
           (matched (word-diff.align ["    Epoxy::Metrics.instance_variable_set(:@configuration, nil)"]
                                     ["  ensure"
                                      "    Epoxy::Metrics.reset_configuration!"]))))

(fn test-align-matches-lines-that-share-interior-words []
  (faith.= [[1 1]]
           (matched (word-diff.align ["aaa bbb ccc ddd"] ["aaa xxx ccc yyy"]))))

{: test-spans-isolate-the-changed-word
 : test-spans-mark-only-the-added-tail
 : test-spans-mark-only-the-removed-head
 : test-spans-split-into-multiple-ranges-around-shared-words
 : test-spans-anchor-the-leftmost-shared-word
 : test-spans-highlight-only-the-extra-leading-space-when-deindented
 : test-spans-highlight-only-the-extra-leading-space-when-indented
 : test-spans-empty-when-lines-match
 : test-align-pairs-equal-length-blocks-by-position
 : test-align-matches-the-similar-line-in-an-unbalanced-block
 : test-align-pairs-by-similarity-regardless-of-position
 : test-align-keeps-pairings-monotonic
 : test-align-leaves-too-different-lines-unmatched
 : test-line-distance-counts-only-word-content
 : test-line-distance-ignores-a-shared-prefix-when-the-rest-differs
 : test-align-skips-pairs-that-only-share-a-prefix
 : test-align-matches-lines-that-share-interior-words}
