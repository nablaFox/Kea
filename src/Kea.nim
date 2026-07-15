import Kea/[core, keys, material, math, primitives, transform]
import std/math

export core, keys, material, math, primitives, transform

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let triangle = kea.add(Triangle, scale = vec3(0.5))

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break 

    triangle.rotation.x = sin(frame.time) * 0.5

    if frame.input.down(Space):
      triangle.rotation.y += 0.01

    kea.render()
