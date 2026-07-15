import math

type Color* = Vec4

const Red*: Color = [1.0, 0.0, 0.0, 1.0]
const Green*: Color = [0.0, 1.0, 0.0, 1.0]
const Blue*: Color  = [0.0, 0.0, 1.0, 1.0]
const White*: Color = [1.0, 1.0, 1.0, 1.0]
const Black*: Color = [0.0, 0.0, 0.0, 1.0]

template r*(v: Color): untyped =
  v[0]

template g*(v: Color): untyped =
  v[1]

template b*(v: Color): untyped =
  v[2]

template a*(v: Color): untyped =
  v[3]
