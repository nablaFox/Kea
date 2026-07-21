import math
import std/math

type
  Transform* = object
    position: Vec3
    rotation: Mat3
    scale: Vec3
    cachedMatrix: Mat4
    dirty: bool

const Identity* = Transform(
  cachedMatrix: Identity4,
  position: vec3(0.0),
  rotation: Identity3,
  scale: vec3(1.0),
  dirty: false
)

proc new*(
  position: Vec3 = vec3(0.0),
  rotation: Mat3 = Identity3,
  scale: Vec3 = vec3(1.0),
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
  pitch: float32 = 0.0,
  yaw: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
): Transform =
  Transform(
    position: [x, y, z],
    rotation: yaw.yaw * pitch.pitch * roll.roll,
    scale: [scale, scale, scale],
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

proc rotMatrix*(transform: Transform): Mat4 =
  let rot = transform.rotation

  [
    [rot[0][0], rot[0][1], rot[0][2], 0.0],
    [rot[1][0], rot[1][1], rot[1][2], 0.0],
    [rot[2][0], rot[2][1], rot[2][2], 0.0],
    [0.0, 0.0, 0.0, 1.0],
  ]

proc transMatrix*(transform: Transform): Mat4 =
  let pos = transform.position

  [
    [1.0'f32, 0.0, 0.0, pos.x],
    [0.0, 1.0, 0.0, pos.y],
    [0.0, 0.0, 1.0, pos.z],
    [0.0, 0.0, 0.0, 1.0],
  ]

proc scaleMatrix*(transform: Transform): Mat4 =
  let scale = transform.scale

  [
    [scale.x, 0.0, 0.0, 0.0],
    [0.0, scale.y, 0.0, 0.0],
    [0.0, 0.0, scale.z, 0.0],
    [0.0, 0.0, 0.0, 1.0],
  ]
 
proc model*(transform: var Transform): Mat4 =
  if not transform.dirty: 
    return transform.cachedMatrix

  let trans = transform.transMatrix

  let scale = transform.scaleMatrix

  let rot = transform.rotMatrix

  transform.cachedMatrix = trans * rot * scale
  transform.dirty = false
    
  transform.cachedMatrix
