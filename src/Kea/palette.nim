import math, color

proc mako(t: float32): Color =
  let dark = [0.045'f, 0.014, 0.070]
  let purple = [0.250'f, 0.105, 0.330]
  let blue = [0.110'f, 0.360, 0.550]
  let teal = [0.120'f, 0.650, 0.610]
  let light = [0.700'f, 0.930, 0.820]

  dark
    .mix(purple, smoothstep(0.0'f, 0.25, t))
    .mix(blue, smoothstep(0.20'f, 0.50, t))
    .mix(teal, smoothstep(0.45'f, 0.75, t))
    .mix(light, smoothstep(0.70'f, 1.0, t))
