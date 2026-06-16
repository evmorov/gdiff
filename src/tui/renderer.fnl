(local registry {})

(fn register [node-type component]
  (tset registry node-type component)
  component)

(fn component-for [node]
  (and node (. registry node.type)))

(fn draw [ctx node]
  (let [component (component-for node)]
    (when component
      (component.draw ctx node))))

(fn registered []
  registry)

{: component-for : draw : register : registered}
