import Kea/[core, keys, material, math, primitives, transform]

export core, keys, material, math, primitives, transform

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let triangle = kea.add(Triangle)

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break

    triangle.transform.position = [1'f32, 2'f32, 3'f32]

    echo frame.delta

    kea.render()
