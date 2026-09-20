import math

type
  Transform* = object
    position: Vec3
    rotation: Mat3
    scale: Vec3
    cachedMatrix: Mat4
    dirty: bool

const Identity* = Transform(
  cachedMatrix: Identity4,
  position: 0.vec3,
  rotation: Identity3,
  scale: 1.vec3,
  dirty: false
)

proc pitch*(value: float32): Mat3 =
  let
    cp = cos(value)
    sp = sin(value)

  [
    [1.0, 0.0, 0.0],
    [0.0, cp, -sp],
    [0.0, sp, cp],
  ]

proc yaw*(value: float32): Mat3 =
  let
    cy = cos(value)
    sy = sin(value)

  [
    [cy, 0.0, sy],
    [0.0, 1.0, 0.0],
    [-sy, 0.0, cy],
  ]

proc roll*(value: float32): Mat3 =
  let
    cr = cos(value)
    sr = sin(value)

  [
    [cr, -sr, 0.0],
    [sr, cr, 0.0],
    [0.0, 0.0, 1.0],
  ]

proc new*(
  position: Vec3 = 0.vec3,
  rotation: Mat3 = Identity3,
  scale: Vec3 = 1.vec3,
): Transform =
  Transform(
    position: position,
    rotation: rotation,
    scale: scale,
    cachedMatrix: Identity4,
    dirty: true,
  )

# convention is: yaw * pitch * roll
proc new*(
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = 1.vec3,
): Transform =
  Transform(
    position: [x, y, z],
    rotation: yaw.yaw * pitch.pitch * roll.roll,
    scale: scale,
    cachedMatrix: Identity4,
    dirty: true,
  )

proc position*(transform: var Transform): var Vec3 =
  transform.dirty = true
  transform.position

proc position*(transform: Transform): Vec3 =
  transform.position

proc scale*(transform: var Transform): var Vec3 =
  transform.dirty = true
  transform.scale

proc scale*(transform: Transform): Vec3 =
  transform.scale

proc rotation*(transform: var Transform): var Mat3 =
  transform.dirty = true
  transform.rotation

proc rotation*(transform: Transform): Mat3 =
  transform.rotation

proc rotMatrix(rot: Mat3): Mat4 =
  [
    [rot[0][0], rot[0][1], rot[0][2], 0.0],
    [rot[1][0], rot[1][1], rot[1][2], 0.0],
    [rot[2][0], rot[2][1], rot[2][2], 0.0],
    [0.0, 0.0, 0.0, 1.0]
  ]

proc transMatrix*(position: Vec3): Mat4 =
  [
    [1.0'f, 0.0, 0.0, position.x],
    [0.0, 1.0, 0.0, position.y],
    [0.0, 0.0, 1.0, position.z],
    [0.0, 0.0, 0.0, 1.0]
  ]

proc scaleMatrix(scale: Vec3): Mat4 =
  [
    [scale.x, 0.0, 0.0, 0.0],
    [0.0, scale.y, 0.0, 0.0],
    [0.0, 0.0, scale.z, 0.0],
    [0.0, 0.0, 0.0, 1.0]
  ]

proc transMatrix*(transform: Transform): Mat4 =
  transform.position.transMatrix

proc scaleMatrix*(transform: Transform): Mat4 =
  transform.scale.scaleMatrix

proc rotMatrix*(transform: Transform): Mat4 =
  transform.rotation.rotMatrix

proc model*(transform: Transform): Mat4 =
  let
    trans = transform.transMatrix

    scale = transform.scaleMatrix

    rot = transform.rotMatrix

  trans * rot * scale

proc model*(transform: var Transform): Mat4 =
  if not transform.dirty:
    return transform.cachedMatrix

  let
    trans = transform.transMatrix

    scale = transform.scaleMatrix

    rot = transform.rotMatrix

  transform.cachedMatrix = trans * rot * scale
  transform.dirty = false

  transform.cachedMatrix
