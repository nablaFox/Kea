import std/math, math, input, camera

type OrbitController* = object
  camera*: Camera
  target*: Vec3
  distance*: float32
  yaw*: float32
  pitch*: float32

proc new*(
  camera: Camera,
  target: Vec3,
  distance: float32 = 10.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
): OrbitController =
  OrbitController(
    camera: camera,
    target: target,
    distance: distance,
    yaw: yaw,
    pitch: pitch
  )

proc update*(
  orbit: var OrbitController, 
  delta: float32,
  mouse: Mouse,
  keyboard: Keyboard,
) = 
  if mouse.down(Left):
    orbit.yaw -= mouse.delta.x * delta * 0.5
    orbit.pitch -= mouse.delta.y * delta * 0.5

    orbit.yaw = clamp(orbit.yaw, -PI, PI)
    orbit.pitch = clamp(orbit.pitch, -PI / 2, 0.0)

  if mouse.down(Middle):
    orbit.target -= orbit.camera.right * mouse.delta.x * 0.005
    orbit.target += orbit.camera.up * mouse.delta.y * 0.005

  orbit.distance *= 0.85 ^ mouse.scroll.y

  let rotation = orbit.yaw.yaw * orbit.pitch.pitch

  orbit.camera.rotation = rotation
  orbit.camera.position = orbit.target + (rotation * WorldBackward) * orbit.distance
