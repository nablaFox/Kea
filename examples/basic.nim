import Kea

let kea = init(
  width = 800, 
  height = 600, 
  title = "basic"
)

var orbit = orbit.new(
  camera.new(Perspective),
  target = [0.0'f32, 1.0, 0.0], 
  distance = 4.0
)

discard kea.add(
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

  orbit.update(frame)

  kea.render(frame.backbuffer, orbit.camera)

  frame.present()
