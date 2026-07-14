import math

type
  Transform* = object
    position: Vec3
    cachedMatrix: Mat4
    dirty: bool

const IdentityTransform* = Transform(
  cachedMatrix: [
    1'f32, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  ],
  position: [0'f32, 0, 0],
  dirty: false
)

proc position*(transform: Transform): Vec3 =
  transform.position

proc `position=`*(transform: var Transform, value: Vec3) =
  transform.position = value
  transform.dirty = true

proc matrix*(transform: Transform): Mat4 =
  if transform.dirty: 
    discard

  transform.cachedMatrix
