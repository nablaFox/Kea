import Kea/[core, keys, material, math, primitives, transform]

export core, keys, material, math, primitives, transform

when isMainModule:
  let kea = initKea(width=800, height=600, title="demo")

  discard kea.add(Triangle)

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break

    echo frame.delta

    kea.render()
