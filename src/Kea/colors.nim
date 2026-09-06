import math, std/math

type Color* = Vec3

const Red*: Color = [1.0, 0.0, 0.0]
const Green*: Color = [0.0, 1.0, 0.0]
const Blue*: Color  = [0.0, 0.0, 1.0]
const White*: Color = [1.0, 1.0, 1.0]
const Black*: Color = [0.0, 0.0, 0.0]

template r*(v: Vec1 | Vec2 | Vec3 | Vec4): untyped =
  v[0]

template g*(v: Vec2 | Vec3 | Vec4): untyped =
  v[1]

template b*(v: Vec3 | Vec4): untyped =
  v[2]

template a*(v: Vec4): untyped =
  v[3]

proc mix*(a, b: Color, t: float32): Color =
  a * (1.0'f - t) + b * t

proc sRGB*(color: Color): Color =
  for i in 0 ..< 3:
    if color[i] <= 0.0031308'f:
      result[i] = 12.92'f * color[i]
    else:
      result[i] =
        1.055'f * pow(color[i], 1.0'f / 2.4'f) - 0.055'f

proc gamma*(color: Color, exponent: float32 = 2.2): Color =
  for i in 0 ..< 3:
    result[i] = pow(color[i], 1.0'f / exponent)
