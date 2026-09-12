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

  light = RectLight(
    position: [0.0'f, 10.0, 0.0],
    radiance: [10.0'f, 8.0'f, 6.0'f],
    rotation: (PI/2).pitch,
    width: 8.0'f,
    height: 8.0'f
  )

var orbit = orbit.new(
  camera.new(Perspective),
  target = [0.0'f, 0.0, 0.0],
  distance = 25.0,
  pitch = -PI / 8
)

discard pbr.add(
  "floor",
  res.mesh(Quad),
  albedo = [0.32'f, 0.38, 0.43],
  roughness = 0.15'f,
  metallic = 0.0'f,
  y = -1.0,
  scale = [10'f, 10, 10],
  pitch = -PI / 2.0
)

discard pbr.add(
  "sphere",
  res.mesh(Sphere)
)

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break

  orbit.update(frame)

  frame.backbuffer.clear()

  pbr.render(
    frame.backbuffer,
    orbit.camera,
    light
  )

  frame.present()
