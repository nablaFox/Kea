import math
import std/math

type
  Transform* = object
    position: Vec3
    rotation: Vec3
    scale: Vec3
    cachedMatrix: Mat4
    dirty: bool

const Identity* = Transform(
  cachedMatrix: IdentityMatrix4,
  position: vec3(0.0),
  rotation: vec3(0.0),
  scale: vec3(1.0),
  dirty: false
)

proc new*(
  position: Vec3 = vec3(0.0),
  rotation: Vec3 = vec3(0.0),
  scale: Vec3 = vec3(1.0),
): Transform =
  Transform(
    position: position,
    rotation: rotation,
    scale: scale,
    cachedMatrix: IdentityMatrix4,
    dirty: true,
  )

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
    rotation: [pitch, yaw, roll],
    scale: [scale, scale, scale],
    cachedMatrix: IdentityMatrix4,
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

proc rotation*(transform: var Transform): var Vec3 =
  transform.dirty = true
  transform.rotation

proc rotation*(transform: Transform): Vec3 =
  transform.rotation

proc pitchMatrix*(transform: Transform): Mat3 =
  let pitch = transform.rotation.x
  let cp = cos(pitch)
  let sp = sin(pitch)

  [
    [1.0, 0.0, 0.0],
    [0.0, cp, -sp],
    [0.0, sp, cp],
  ]

proc yawMatrix*(transform: Transform): Mat3 =
  let yaw = transform.rotation.y
  let cy = cos(yaw)
  let sy = sin(yaw)

  [
    [cy, 0.0, sy],
    [0.0, 1.0, 0.0],
    [-sy, 0.0, cy],
  ]

proc rollMatrix*(transform: Transform): Mat3 =
  let roll = transform.rotation.z
  let cr = cos(roll)
  let sr = sin(roll)

  [
    [cr, -sr, 0.0],
    [sr, cr, 0.0],
    [0.0, 0.0, 1.0],
  ]

proc rotMatrix3*(transform: Transform): Mat3 =
  transform.yawMatrix * transform.pitchMatrix * transform.rollMatrix

proc rotMatrix*(transform: Transform): Mat4 =
  let rot = transform.rotMatrix3

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
