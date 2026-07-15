import math
import std/math

type
  Transform* = object
    position: Vec3
    rotation: Vec3
    scale: Vec3
    cachedMatrix: Mat4
    dirty: bool

const IdentityMatrix = identity[4]()

const IdentityTransform* = Transform(
  cachedMatrix: IdentityMatrix,
  position: vec3(0.0),
  rotation: vec3(0.0),
  scale: vec3(1.0),
  dirty: false
)

proc transform*(position = vec3(0.0), rotation = vec3(0.0), scale = vec3(1.0)): Transform =
  Transform(
    position: position,
    rotation: rotation,
    scale: scale,
    cachedMatrix: IdentityMatrix,
    dirty: true
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
  
proc matrix*(transform: var Transform): Mat4 =
  if not transform.dirty: 
    return transform.cachedMatrix

  let trans = block:
    let pos = transform.position

    [
      [1.0'f32, 0.0, 0.0, pos.x],
      [0.0, 1.0, 0.0, pos.y],
      [0.0, 0.0, 1.0, pos.z],
      [0.0, 0.0, 0.0, 1.0],
    ] 

  let scale = block:
    let scale = transform.scale

    [
      [scale.x, 0.0, 0.0, 0.0],
      [0.0, scale.y, 0.0, 0.0],
      [0.0, 0.0, scale.z, 0.0],
      [0.0, 0.0, 0.0, 1.0],
    ]

  let rot = block:
    let rot = transform.rotation

    let pitch = rot.x
    let yaw = rot.y
    let roll = rot.z

    let cp = cos(pitch)
    let sp = sin(pitch)
    let cy = cos(yaw)
    let sy = sin(yaw)
    let cr = cos(roll)
    let sr = sin(roll)

    [
      [cy * cr, -cy * sr, sy, 0.0],
      [sp * sy * cr + cp * sr, -sp * sy * sr + cp * cr, -sp * cy, 0.0],
      [-cp * sy * cr + sp * sr, cp * sy * sr + sp * cr, cp * cy, 0.0],
      [0.0, 0.0, 0.0, 1.0],
    ]

  transform.cachedMatrix = trans.multiply(rot).multiply(scale)
  transform.dirty = false
    
  transform.cachedMatrix
