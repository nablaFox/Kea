import std/math, math, input, camera

type OrbitController* = object
  camera*: Camera
  target*: Vec3
  home*: Vec3
  distance*: float32
  yaw*: float32
  pitch*: float32

const
  BaseRotationSensitivity = 0.002'f
  BasePanSensitivity = 0.000625'f

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
    home: target,
    distance: distance,
    yaw: yaw,
    pitch: pitch
  )

proc update*(
  orbit: var OrbitController, 
  delta: float32,
  mouse: Mouse,
  keyboard: Keyboard,
  rotationSensitivity: float32 = 1.0'f,
  panSensitivity: float32 = 1.0'f
) = 
  if keyboard.pressed(Home):
    orbit.target = orbit.home
    orbit.yaw = 0.0'f
    orbit.pitch = 0.0'f

  let t = 1.0'f - exp(-12.0'f * delta)

  let distance = block:
    let currDistance = (orbit.camera.positioned - orbit.target).length
    let smoothDistance = lerp(currDistance, orbit.distance, t)

    smoothDistance

  if keyboard.down(LeftShift):
    let sensitivity = BaseRotationSensitivity * rotationSensitivity

    orbit.yaw -= mouse.delta.x * sensitivity
    orbit.pitch -= mouse.delta.y * sensitivity

    orbit.yaw = clamp(orbit.yaw, -PI, PI)
    orbit.pitch = clamp(orbit.pitch, -PI / 2, 0.0)

  if keyboard.down(LeftAlt):
    let speed =
      BasePanSensitivity * panSensitivity * distance

    orbit.target -= orbit.camera.right * mouse.delta.x * speed
    orbit.target += orbit.camera.up * mouse.delta.y * speed

  let rotation = orbit.yaw.yaw * orbit.pitch.pitch

  orbit.distance *= 0.85 ^ mouse.scroll.y
 
  orbit.camera.position = orbit.target + (rotation * WorldBackward) * distance

  orbit.camera.rotation = rotation
