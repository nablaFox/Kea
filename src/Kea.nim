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
    input
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
  input

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let triangle = kea.add(Triangle, z = -5.0)

  for frame in kea.frames:
    if frame.input.pressed(Escape):
      break 

    triangle.rotation.x = sin(frame.time) * 0.5

    if frame.input.down(Space):
      triangle.rotation.y += 0.01

    if frame.input.pressed(Tab):
      kea.camera.kind = if kea.camera.kind == Perspective: Orthographic else: Perspective

    if frame.input.down(Up):
      kea.camera.size -= 0.1

    if frame.input.down(Down):
      kea.camera.size += 0.1

    if frame.input.down(Left):
      kea.camera.position.x -= 0.1

    if frame.input.down(Right):
      kea.camera.position.x += 0.1

    kea.render()
