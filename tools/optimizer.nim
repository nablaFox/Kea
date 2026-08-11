import Kea/math
import std/algorithm

const
  MaxIterations = 500
  Tolerance = 1e-6'f

  Reflection = 1.0'f
  Expansion = 2.0'f
  Contraction = 0.5'f
  Shrink = 0.5'f

  InitialStep = 0.05'f

proc optimize*[K: static int](
  initial: Vec[K],
  error: proc(params: Vec[K]): float32
): Vec[K] =
  type Point = tuple[
    params: Vec[K],
    value: float32
  ]

  proc evaluate(params: Vec[K]): Point =
    (params: params, value: error(params))

  proc along(a, b: Vec[K], amount: float32): Vec[K] =
    for i in 0 ..< K:
      result[i] = a[i] + amount * (b[i] - a[i])

  proc compare(a, b: Point): int =
    cmp(a.value, b.value)

  var simplex: array[K + 1, Point]

  simplex[0] = evaluate(initial)

  for axis in 0 ..< K:
    var params = initial
    params[axis] += InitialStep
    simplex[axis + 1] = evaluate(params)

  for _ in 0 ..< MaxIterations:
    simplex.sort(compare)

    let best = simplex[0]

    var
      parameterSpread = 0.0'f
      valueSpread = 0.0'f
      parameterScale = 1.0'f

    for value in best.params:
      parameterScale = max(parameterScale, abs(value))

    for i in 1 .. K:
      valueSpread = max(
        valueSpread,
        abs(simplex[i].value - best.value)
      )

      for axis in 0 ..< K:
        parameterSpread = max(
          parameterSpread,
          abs(simplex[i].params[axis] - best.params[axis])
        )

    if parameterSpread <= Tolerance * parameterScale and
       valueSpread <= Tolerance * max(1.0'f, abs(best.value)):
      break

    var centroid: Vec[K]

    for i in 0 ..< K:
      for axis in 0 ..< K:
        centroid[axis] += simplex[i].params[axis]

    for axis in 0 ..< K:
      centroid[axis] /= K.float32

    let
      worst = simplex[K]
      reflected = evaluate(
        along(centroid, worst.params, -Reflection)
      )

    if reflected.value < best.value:
      let expanded = evaluate(
        along(centroid, reflected.params, Expansion)
      )

      simplex[K] =
        if expanded.value < reflected.value: expanded
        else: reflected

    elif reflected.value < simplex[K - 1].value:
      simplex[K] = reflected

    else:
      let target =
        if reflected.value < worst.value: reflected
        else: worst

      let contracted = evaluate(
        along(centroid, target.params, Contraction)
      )

      if contracted.value <= target.value:
        simplex[K] = contracted
      else:
        for i in 1 .. K:
          simplex[i] = evaluate(
            along(best.params, simplex[i].params, Shrink)
          )

  simplex.sort(compare)
  simplex[0].params

proc optimize*(
  initial: float32,
  error: proc(param: float32): float32
): float32 =
  optimize[1](
    initial = [initial],
    error = proc(params: Vec[1]): float32 =
      error(params[0])
  )[0]
