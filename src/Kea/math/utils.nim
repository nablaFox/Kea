import std/math

proc invsqrt*(x: float32): float32 =
  1 / sqrt(x)

proc lerp*(a, b, t: float32): float32 =
  a + (b - a) * t

proc smoothstep*(a, b, x: float32): float32 =
  let t = ((x - a) / (b - a)).clamp(0.0, 1.0)
  t * t * (3.0 - 2.0 * t)

proc mix*(a, b, t: float32): float32 =
  a * (1.0'f - t) + b * t

proc fwidth*(x: float32): float32 =
  discard
