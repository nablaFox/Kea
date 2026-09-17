import math

type
  Color* = Vec3

const
  Red*: Color = [1.0, 0.0, 0.0]
  Green*: Color = [0.0, 1.0, 0.0]
  Blue*: Color  = [0.0, 0.0, 1.0]
  White*: Color = [1.0, 1.0, 1.0]
  Black*: Color = [0.0, 0.0, 0.0]

template r*(v: Vec1 | Vec2 | Vec3 | Vec4): untyped =
  v[0]

template g*(v: Vec2 | Vec3 | Vec4): untyped =
  v[1]

template b*(v: Vec3 | Vec4): untyped =
  v[2]

template a*(v: Vec4): untyped =
  v[3]

proc gamma*(color: Color, exponent: float32 = 2.2): Color =
  for i in 0 ..< 3:
    result[i] = pow(color[i], 1.0'f / exponent)

proc rgbToYCoCg*(c: Color): Color =
  [
    0.25'f * c.x + 0.5'f * c.y + 0.25'f * c.z,
    0.5'f * c.x - 0.5'f * c.z,
    -0.25'f * c.x + 0.5'f * c.y - 0.25'f * c.z
  ]

proc ycocgToRgb*(c: Color): Color =
  [
    c.x + c.y - c.z,
    c.x + c.z,
    c.x - c.y - c.z
  ]
