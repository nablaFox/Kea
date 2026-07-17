import std/math, transform, math

type 
  CameraKind* = enum
    Perspective
    Orthographic

  Camera* = object
    transform*: Transform
    kind*: CameraKind
    fov*: float32
    near*: float32
    far*: float32
    size*: float32

proc new*(kind: CameraKind, fov = 60.0'f32, near = 0.1'f32, far = 100.0'f32, size = 10.0'f32): Camera =
  Camera(
    transform: IdentityTransform,
    kind: kind,
    fov: fov,
    near: near,
    far: far,
    size: size
  )

proc view*(camera: Camera): Mat4 = 
  let rotTransposed = camera.transform.rotMatrix.transpose

  let transInverted = transform.new(position = camera.transform.position * -1.0).transMatrix

  rotTransposed * transInverted

proc proj*(camera: Camera, aspect: float32): Mat4 =
  let near = camera.near
  let far = camera.far

  case camera.kind

  of Perspective:
    let fov = camera.fov
    let top = tan(fov * 0.5 * (PI / 180.0)) * near
    let right = top * aspect

    let a = float32(near / right)
    let b = near / top
    let c = (far + near) / (near - far)
    let d = (2.0 * far * near) / (near - far)

    [
      [a,   0.0, 0.0,  0.0],
      [0.0, b,   0.0,  0.0],
      [0.0, 0.0, c,    d],
      [0.0, 0.0, -1.0, 0.0]
    ]

  of Orthographic:
    let top = camera.size
    let right = top * aspect

    let a = float32(1.0 / right)
    let b = 1.0 / top
    let c = 2.0 / (near - far)
    let d = (far + near) / (near - far)

    [
      [a,   0.0, 0.0, 0.0],
      [0.0, b,   0.0, 0.0],
      [0.0, 0.0, c,   d],
      [0.0, 0.0, 0.0, 1.0]
    ]

proc transform*(camera: var Camera): var Transform =
  camera.transform

proc position*(camera: var Camera): var Vec3 =
  camera.transform.position

proc positioned*(camera: Camera): Vec3 =
  let transform = camera.transform
  transform.position

proc rotation*(camera: var Camera): var Vec3 =
  camera.transform.rotation

proc rotated*(camera: Camera): Vec3 =
  let transform = camera.transform
  transform.rotation
