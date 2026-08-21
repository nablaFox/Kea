import colors, std/math

proc reinhard*(color: Color): Color =
  for i in 0..<3:
    result[i] = color[i] / (1.0 + color[i])

proc exponential*(color: Color, exposure: float32 = 1.0): Color =
  for i in 0..<3:
    result[i] = 1.0 - exp(-color[i] * exposure)
