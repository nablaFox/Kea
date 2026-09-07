import math

type
  RectLight* = object
    position*: Vec3
    rotation*: Mat3 = Identity3
    width*: float32 = 1.0
    height*: float32 = 1.0
    radiance*: Vec3

proc corners*(light: RectLight): array[4, Vec3] =
  let
    right = light.rotation * [-1.0'f, 0.0, 0.0]
    up = light.rotation * [0.0'f, 1.0, 0.0]
    x = right * light.width / 2.0
    y = up * light.height / 2.0
    center = light.position

  [
    center - y - x,
    center + x - y,
    center + x + y,
    center - x + y
  ]
