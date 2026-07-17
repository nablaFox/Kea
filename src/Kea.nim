import 
  Kea/[
    core, 
    keys, 
    material, 
    math, 
    primitives, 
    transform, 
    camera, 
    drawable, 
    mesh, 
    input,
    colors
  ], 
  std/math

export 
  core, 
  keys, 
  material, 
  math, 
  primitives, 
  transform, 
  camera, 
  drawable, 
  mesh, 
  input,
  colors

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let triangle = kea.add(Triangle, z = -4.5, material = Red)  

  discard kea.add(Sphere, z = -4.0, y = 1.5, x = 1.5, scale = 0.1)

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break 

    if frame.input.down(Left):
      triangle.rotation.y -= frame.delta

    if frame.input.down(Right):
      triangle.rotation.y += frame.delta

    if frame.input.down(Up):
      triangle.rotation.x -= frame.delta

    if frame.input.down(Down):
      triangle.rotation.x += frame.delta

    kea.render(clear = Black)
