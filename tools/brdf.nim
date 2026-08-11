import Kea/math, std/math, optimizer

type
  Brdf* = concept brdf
    eval(brdf, Vec3, Vec3) is tuple[value: float32, pdf: float32]
    sample(brdf, Vec3, Vec2) is Vec3

proc average*(brdf: Brdf, wo: Vec3, resolution: Natural): tuple[
  direction: Vec3, 
  fresnel: float32, 
  magnitude: float32,
] = 
  var 
    direction = vec3(0.0)
    magnitude = 0.0'f
    fresnel = 0.0'f

  for i in 0..<resolution:
    for j in 0..<resolution:
      let U: Vec2 = [
        (i.float32 + 0.5'f) / resolution.float32,
        (j.float32 + 0.5'f) / resolution.float32
      ]

      let wi = brdf.sample(wo, U)

      let (value, pdf) = brdf.eval(wi, wo)

      if pdf > 0.0'f:
        let weight = value / pdf
        let H = (wo + wi).normalize

        direction += wi * weight;
        magnitude += weight;
        fresnel += weight * (1.0 - max(dot(wo, H), 0.0'f))^5
    
  direction.y = 0.0

  let samples = (resolution * resolution).float32

  (
    direction: direction.normalize,
    fresnel: fresnel / samples,
    magnitude: magnitude / samples,
  )

proc anisotropicShape(params: Vec3): Mat3 {.inline} =
  let x = params.x
  let b = params.y
  let z = params.z

  let a = exp(x)
  let c = exp(z)

  [
    [a,   0.0, b],
    [0.0, c,   0.0],
    [0.0, 0.0, 1.0]
  ]

proc isotropicShape(param: float32): Mat3 {.inline} =
  let scale = exp(param)

  [
    [scale, 0.0,   0.0],
    [0.0,   scale, 0.0],
    [0.0,   0.0,   1.0]
  ]

proc nearNormal(v: Vec3): bool {.inline} =
  abs(v.x) < 1e-6'f and
  abs(v.y) < 1e-6'f and
  abs(v.z - 1.0'f) < 1e-6'f

proc aproximation(matrix: Mat3, wi: Vec3): float32 = 
  let inverse = matrix.inverse

  let p = inverse * wi

  let length = p.length

  if length < 1e-7'f:
    return 0.0'f 

  let source = p / length

  if source.z <= 0.0'f:
    return 0.0'f

  let jacobian = abs(inverse.det) / length^3

  source.z / PI * jacobian

proc sampleLtc(matrix: Mat3, U: Vec2): Vec3 {.inline.} =
  let
    phi = 2.0'f * PI * U.y
    z = sqrt(U.x)
    r = sqrt(1.0'f - U.x)

  let source: Vec3 = [
    (r * cos(phi)).float32,
    (r * sin(phi)).float32,
    z.float32
  ]

  (matrix * source).normalize

proc error(
  brdf: Brdf, 
  matrix: Mat3, 
  wo: Vec3,
  magnitude: float32,
  resolution: Natural
): float32 = 
  proc accumulate(wi: Vec3): float32 =
    let 
      (valueBrdf, pdfBrdf) = brdf.eval(wi, wo)

      pdfLtc = matrix.aproximation(wi)

      valueLtc = magnitude * pdfLtc

      denom = pdfBrdf + pdfLtc

    if denom <= 1e-7'f:
      return 0.0'f

    let diff = abs(valueBrdf - valueLtc)

    diff^3 / denom

  for j in 0..<resolution:
    for i in 0..<resolution:
      let U: Vec2 = [
        (i.float32 + 0.5'f) / resolution.float32,
        (j.float32 + 0.5'f) / resolution.float32
      ]
      
      # LTC importance sampling
      result += accumulate(matrix.sampleLtc(U))

      # BRDF importance sampling 
      result += accumulate(brdf.sample(wo, U))

  result /= (resolution * resolution).float32


proc fit*(
  brdf: Brdf, 
  wo: Vec3, 
  resolution: Natural,
  initialScale = 1.0'f
): tuple[
  matrix: Mat3,
  fresnel: float32,
  magnitude: float32,
] = 
  let (direction, fresnel, magnitude) = brdf.average(wo, resolution)

  if magnitude < 1e-7'f:
    return (
      matrix: Identity3,
      fresnel: fresnel,
      magnitude: magnitude
    )

  let normal = wo.nearNormal

  let basis =
    if normal: Identity3
    else:
      let Z = direction
      let X = [Z.z, 0.0'f, -Z.x]
      let Y = [0.0'f, 1.0'f, 0.0'f]

      [X, Y, Z].transpose

  let matrix =
    if normal:
      let param = optimizer.optimize(
        initial = ln(max(initialScale, 1e-7'f)),
        error = proc(param: float32): float32 =
          brdf.error(
            matrix = basis * param.isotropicShape,
            wo,
            magnitude,
            resolution
          )
      )

      basis * param.isotropicShape

    else:
      let params = optimizer.optimize(
        initial = [0.0'f, 0.0, 0.0],
        error = proc(params: Vec3): float32 =
          brdf.error(
            matrix = basis * params.anisotropicShape,
            wo,
            magnitude,
            resolution
          )
      )

      basis * params.anisotropicShape

  (
    matrix: matrix, 
    fresnel: fresnel, 
    magnitude: magnitude
  )
