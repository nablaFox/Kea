import Kea/[core, keys, material, math, primitives, transform, camera]
import std/math

export core, keys, material, math, primitives, transform, camera

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let triangle = kea.add(Triangle, scale = vec3(0.5), position = [0.0'f32, 0.0, -2.0])

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break 

    triangle.rotation.x = sin(frame.time) * 0.5

    if frame.input.down(Space):
      triangle.rotation.y += 0.01

    kea.render()
