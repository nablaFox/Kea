import 
  Kea/[
    core, 
    pbr,
    renderer, 
    math, 
    primitives, 
    transform, 
    camera, 
    mesh, 
    input,
    colors,
    orbit
  ], 
  std/math

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

  var component = 0

  for frame in kea.frames:
    if frame.keyboard.pressed(Escape):
      break 

    kea.camera = kea.orbit.camera

    kea.render(clear = Black)
