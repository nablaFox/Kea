import math

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
  discard

proc sRGB*(color: Color): Color =
  discard
