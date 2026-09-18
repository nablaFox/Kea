import Kea

let
  kea = init(
    title = "pbr",
    width = 800,
    height = 600,
    cursor = Disabled
  )

  res = resources.new(kea)

  pbr = pbr.new(res)

  orbit = orbit.new(
    camera.new(Perspective),
    target = [0.0'f, 0.0, 0.0],
    distance = 25.0,
    pitch = -PI / 8
  )

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break

  orbit.update(frame)

  frame.backbuffer.clear()

  pbr.submit(
    res.mesh(Quad),
    y = -1.0,
    scale = [10'f, 10, 10],
    pitch = -PI / 2.0,
    material = (
      prevModel: Identity4,
      albedo: [0.32'f, 0.38, 0.43],
      roughness: 0.15'f,
      metallic: 0.0'f
    )
  )

  pbr.submit res.mesh(Sphere)

  pbr.render(
    frame.backbuffer,
    orbit.camera,
    RectLight(
      position: [0.0'f, 10.0, 0.0],
      radiance: [10.0'f, 8.0'f, 6.0'f],
      rotation: (PI/2).pitch,
      width: 8.0'f,
      height: 8.0'f
    )
  )

  frame.present()
