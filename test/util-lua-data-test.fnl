(local faith (require :faith))
(local lua-data (require :util.lua-data))
(local sys (require :platform.core))

(fn round-trip [value]
  (let [(ok result) (sys.load-data (lua-data.serialize value) "test")]
    (faith.is ok result)
    result))

(fn test-round-trips-nested-tables-with-hyphenated-keys []
  (let [value {:lines ["a" "b"]
               :old-no 3
               :side :new
               :refs [false {:side :old :no 1}]
               :split [{:kind :change :old-move {:line 2}}]}]
    (faith.= value (round-trip value))))

(fn test-round-trips-strings-with-control-characters []
  (let [value ["quote \" and \\ backslash"
               "line\nbreak\r"
               "\027[31mred\027[0m"
               "nul\000inside"
               "tab\tand ünïcode"]]
    (faith.= value (round-trip value))))

(fn test-round-trips-numbers-and-booleans []
  (let [value {:int 42 :neg -7 :float 0.1 :big 1e300 :yes true :no false}]
    (faith.= value (round-trip value))
    (faith.= :integer (math.type (. (round-trip [42]) 1)))))

(fn test-keeps-false-holes-in-arrays []
  (let [value [false 1 false 2]]
    (faith.= value (round-trip value))
    (faith.= 4 (length (round-trip value)))))

(fn test-rejects-functions-and-cycles []
  (let [cycle {}]
    (set cycle.self cycle)
    (faith.error "cannot serialize a function"
                 #(lua-data.serialize {:f (fn [])}))
    (faith.error "cannot serialize a table cycle" #(lua-data.serialize cycle))))

(fn test-reuses-a-table-that-is-not-a-cycle []
  (let [shared [1 2]]
    (faith.= {:a [1 2] :b [1 2]} (round-trip {:a shared :b shared}))))

(fn test-load-data-runs-with-an-empty-environment []
  (faith.= [true nil] [(sys.load-data "return os" "test")])
  (faith.= false (sys.load-data "return {" "test")))

{: test-keeps-false-holes-in-arrays
 : test-load-data-runs-with-an-empty-environment
 : test-rejects-functions-and-cycles
 : test-reuses-a-table-that-is-not-a-cycle
 : test-round-trips-nested-tables-with-hyphenated-keys
 : test-round-trips-numbers-and-booleans
 : test-round-trips-strings-with-control-characters}
