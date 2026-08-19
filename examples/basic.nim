import Kea

let kea = init(
  width = 800, 
  height = 600, 
  title = "basic",
  cursor = Disabled
)

var orbit = orbit.new(
  camera.new(Perspective),
  target = [0.0'f, 0.0, 0.0], 
  distance = 25.0,
  pitch = -PI / 8
)

discard kea.add(
  Quad, 
  (
    albedo: [0.32'f, 0.38, 0.43],
    roughness: 0.5'f, 
    metallic: 0.0'f
  ),
  x = 0, 
  y = -1.0, 
  scale = 10, 
  pitch = -PI / 2.0
)

discard kea.add(
  Sphere, 
  (
    albedo: [0.8'f, 0.38, 0.43],
    roughness: 0.2'f, 
    metallic: 0.0'f
  ),
  x = 0, 
  y = 0, 
)
  
kea.light.position = [0.0'f, 10.0, 0.0]
kea.light.radiance = [10.0'f, 8.0'f, 6.0'f]
kea.light.rotation = (PI/2).pitch
kea.light.width = 8.0'f
kea.light.height = 8.0'f

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break 

  orbit.update(frame)

  frame.backbuffer.clear()

  kea.render(frame.backbuffer, orbit.camera)

  frame.present()
