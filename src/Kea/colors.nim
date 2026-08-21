import math

type Color* = Vec3

const Red*: Color = [1.0, 0.0, 0.0]
const Green*: Color = [0.0, 1.0, 0.0]
const Blue*: Color  = [0.0, 0.0, 1.0]
const White*: Color = [1.0, 1.0, 1.0]
const Black*: Color = [0.0, 0.0, 0.0]

proc mix*(a, b: Color, t: float32): Color = 
  discard

proc sRGB*(color: Color): Color =
  discard
