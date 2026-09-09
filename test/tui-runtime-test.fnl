(local faith (require :faith))
(local runtime (require :tui.runtime))

(fn program [keys ?coalescible]
  (let [state {:skip_next_draw? false
               :force_next_draw? false
               :quick_frame? false}
        frames []
        updates []
        coalescible (or ?coalescible {:j true :k true})]
    (var index 0)
    {: state
     : frames
     : updates
     :view #nil
     :read-key (fn [_state]
                 (set index (+ index 1))
                 (or (. keys index) :tick))
     :draw (fn [_view state]
             (table.insert frames (if state.quick_frame? :quick :full)))
     :update (fn [state key]
               (table.insert updates key)
               (set state.skip_next_draw? (or (= key :noop) (= key :tick)))
               (not= key "q"))
     :coalesce? (fn [_state key] (. coalescible key))}))

(fn test-burst-draws-quick-frames-until-input-settles []
  (let [p (program ["j" "k" :tick])
        (running held) (runtime.run-burst p)]
    (faith.= true running)
    (faith.= nil held)
    (faith.= ["j" "k"] p.updates)
    (faith.= [:quick :quick] p.frames)
    (faith.= true p.state.force_next_draw?)
    (faith.= false p.state.skip_next_draw?)
    (faith.= false p.state.quick_frame?)))

(fn test-burst-without-further-keys-skips-the-next-frame []
  (let [p (program [:tick])]
    (runtime.run-burst p)
    (faith.= [] p.frames)
    (faith.= true p.state.skip_next_draw?)
    (faith.= false p.state.force_next_draw?)))

(fn test-burst-holds-a-key-it-cannot-coalesce []
  (let [p (program ["j" "o"])
        (running held) (runtime.run-burst p)]
    (faith.= true running)
    (faith.= "o" held)
    (faith.= ["j"] p.updates)
    (faith.= [:quick] p.frames)))

(fn test-burst-stops-when-update-quits []
  (let [p (program ["j" "q"] {:j true :q true})
        (running held) (runtime.run-burst p)]
    (faith.= false running)
    (faith.= nil held)
    (faith.= ["j" "q"] p.updates)
    (faith.= [:quick] p.frames)))

(fn test-burst-skips-quick-frame-after-a-no-op-update []
  (let [p (program [:noop :tick] {:noop true})]
    (runtime.run-burst p)
    (faith.= [] p.frames)))

(fn test-loop-draws-first-key-in-full-and-settles-with-a-full-frame []
  (let [p (program ["j" "j" :tick "q"])]
    (runtime.loop p)
    (faith.= ["j" "j" "q"] p.updates)
    (faith.= [:full :full :quick :full] p.frames)))

(fn test-loop-does-not-redraw-a-single-tap-after-it-settles []
  (let [p (program ["j" :tick "q"])]
    (runtime.loop p)
    (faith.= ["j" "q"] p.updates)
    (faith.= [:full :full] p.frames)))

(fn test-loop-handles-the-held-key-without-an-extra-frame []
  (let [p (program ["j" "o" "q"])]
    (runtime.loop p)
    (faith.= ["j" "o" "q"] p.updates)
    (faith.= [:full :full :full] p.frames)))

(fn test-loop-skips-frames-for-idle-ticks []
  (let [p (program [:tick :tick "q"] {})]
    (runtime.loop p)
    (faith.= [:tick :tick "q"] p.updates)
    (faith.= [:full] p.frames)
    (faith.= 2 p.state.tick_count)))

{: test-burst-draws-quick-frames-until-input-settles
 : test-burst-without-further-keys-skips-the-next-frame
 : test-burst-holds-a-key-it-cannot-coalesce
 : test-burst-stops-when-update-quits
 : test-burst-skips-quick-frame-after-a-no-op-update
 : test-loop-draws-first-key-in-full-and-settles-with-a-full-frame
 : test-loop-does-not-redraw-a-single-tap-after-it-settles
 : test-loop-handles-the-held-key-without-an-extra-frame
 : test-loop-skips-frames-for-idle-ticks}
