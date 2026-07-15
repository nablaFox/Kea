import Kea/[core, keys, material, math, primitives, transform]

export core, keys, material, math, primitives, transform

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let triangle = kea.add(Triangle, scale = vec3(0.5))

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break 

    if frame.input.down(Space):
      triangle.rotation.y += 0.01

    kea.render()
