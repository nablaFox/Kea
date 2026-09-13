import transform, math

const
  WorldOrigin*: Vec3 = [0.0, 0.0, 0.0]
  WorldBackward*: Vec3 = [0.0, 0.0, 1.0]
  WorldForward*: Vec3 = [0.0, 0.0, -1.0]
  WorldUp*: Vec3 = [0.0, 1.0, 0.0]
  WorldRight*: Vec3 = [1.0, 0.0, 0.0]
  WorldLeft*: Vec3 = [-1.0, 0.0, 0.0]

type
  CameraKind* = enum
    Perspective
    Orthographic

  CameraObj* = object
    transform*: Transform
    kind*: CameraKind
    fov*: float32
    near*: float32
    far*: float32
    size*: float32

  Camera* = ref CameraObj

proc new*(
  kind: CameraKind,
  fov = 60.0'f,
  near = 0.1'f,
  far = 100.0'f,
  size = 10.0'f,
  transform = Identity
): Camera =
  Camera(
    transform: transform,
    kind: kind,
    fov: fov,
    near: near,
    far: far,
    size: size
  )

proc transform*(camera: Camera): var Transform =
  camera.transform

proc position*(camera: Camera): var Vec3 =
  camera.transform.position

proc positioned*(camera: Camera): Vec3 =
  let transform = camera.transform
  transform.position

proc rotation*(camera: Camera): var Mat3 =
  camera.transform.rotation

proc rotated*(camera: Camera): Mat3 =
  let transform = camera.transform
  transform.rotation

proc forward*(camera: Camera): Vec3 =
  camera.transform.rotation * WorldForward

proc right*(camera: Camera): Vec3 =
  camera.transform.rotation * WorldRight

proc up*(camera: Camera): Vec3 =
  camera.transform.rotation * WorldUp

proc view*(camera: Camera): Mat4 =
  let
    rotTransposed = camera
      .transform
      .rotMatrix
      .transpose

    transInverted = transform.new(
      position = - camera.positioned
    )

  rotTransposed * transInverted.transMatrix

proc proj*(camera: Camera, aspect: float32): Mat4 =
  let
    near = camera.near
    far = camera.far

  doAssert aspect > 0.0'f
  doAssert far > near
  doAssert near > 0.0'f

  case camera.kind
  of Perspective:
    let
      fov = camera.fov
      top = tan(fov * 0.5 * (PI / 180.0)) * near
      right = top * aspect

    doAssert fov > 0.0'f and fov < 180.0'f

    let
      a = float32(near / right)
      b = near / top
      c = (far + near) / (near - far)
      d = (2.0 * far * near) / (near - far)

    [
      [a,   0.0, 0.0,  0.0],
      [0.0, b,   0.0,  0.0],
      [0.0, 0.0, c,    d],
      [0.0, 0.0, -1.0, 0.0]
    ]

  of Orthographic:
    let
      top = camera.size
      right = top * aspect

    doAssert top > 0.0'f

    let
      a = float32(1.0 / right)
      b = 1.0 / top
      c = 2.0 / (near - far)
      d = (far + near) / (near - far)

    [
      [a,   0.0, 0.0, 0.0],
      [0.0, b,   0.0, 0.0],
      [0.0, 0.0, c,   d],
      [0.0, 0.0, 0.0, 1.0]
    ]
