import 
  Kea/[
    core, 
    pbr,
    renderer, 
    math, 
    target,
    primitives, 
    transform, 
    camera, 
    mesh, 
    input,
    colors,
    orbit
  ], 
  std/math,
  nimgl/opengl

export 
  core, 
  renderer, 
  math, 
  primitives, 
  transform, 
  camera, 
  pbr,
  mesh, 
  input,
  colors,
  orbit

when isMainModule:
  let kea = core.init(
    width = 800, 
    height = 600, 
    title = "demo",
    orbit = orbit.new(target = [0.0'f32, 1.0, 0.0], distance = 4.0)
  )

  discard kea.pbr.add(
    Quad, 
    (
      albedo: [0.32'f32, 0.38, 0.43],
      roughness: 0.85'f32, 
      metallic: 0.0'f32
    ),
    x = 0, 
    y = -1.0, 
    scale = 10, 
    pitch = -PI / 2.0
  )

  for frame in kea.frames:
    if frame.keyboard.pressed(Escape):
      break 

    frame.backbuffer.clear()

    kea.camera = kea.orbit.camera

    kea.pbr.eye = kea.camera.position
    kea.pbr.view = kea.camera.view
    kea.pbr.proj = kea.camera.proj frame.aspect

    kea.pbr.render(frame.backbuffer)

    frame.present()
