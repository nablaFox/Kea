import std/os, std/strformat, std/math, Kea/[math, ltc], brdf

type 
  GgxBrdf = object
    alpha: float32

proc sample(ggx: GgxBrdf, wo: Vec3, u: Vec2): Vec3 = 
  let phi = 2.0'f32 * PI.float32 * u.x

  let radius = ggx.alpha * sqrt(u.y / (1.0'f32 - u.y))

  let normal = [radius * cos(phi), radius * sin(phi), 1.0].normalize

  let wi = reflect(-wo, normal)

  return wi

proc eval(
  ggx: GgxBrdf,
  wi, wo: Vec3
): tuple[value: float32, pdf: float32] =
  if wo.z <= 0.0'f:
    return

  let
    h = wo + wi
    hLen = h.length

  if hLen <= 1e-7'f:
    return

  let
    H = h / hLen
    woDotH = dot(wo, H)

  if abs(woDotH) <= 1e-7'f:
    return

  let
    alpha2 = ggx.alpha * ggx.alpha
    denom = 1.0'f + (alpha2 - 1.0'f) * H.z * H.z
    D = alpha2 / (PI * denom * denom)

  result.pdf = abs(D * H.z / (4.0'f * woDotH))

  if wi.z <= 0.0'f:
    return

  proc lambda(cosTheta: float32): float32 =
    let
      cos2 = cosTheta * cosTheta
      tan2 = max(0.0'f, 1.0'f - cos2) / cos2

    0.5'f * (sqrt(1.0'f + alpha2 * tan2) - 1.0'f)

  let G = 1.0'f / (1.0'f + lambda(wo.z) + lambda(wi.z))

  result.value = D * G / (4.0'f * wo.z)

const
  ProjectRoot = currentSourcePath().parentDir.parentDir
  OutputDir = ProjectRoot / "src" / "Kea" / "data" / "ltc"
  N = ltc.LutSize
  Total = N * N

createDir(OutputDir)

let inverseMatrixFile = open(OutputDir / "inverse_matrix.rgba32f.bin", fmWrite)

let magnitudeFresnelFile = open(OutputDir / "magnitude_fresnel.rg32f.bin", fmWrite)

var completed = 0

for viewIndex in 0 ..< N:
  for roughnessIndex in 0 ..< N:
    let theta = block:
      let x = viewIndex / (N - 1)
      min(PI / 2, arccos(1.0 - x^2))

    let view = [sin(theta).float32, 0.0, cos(theta).float32]

    let alpha = max((roughnessIndex / (N - 1))^2, 0.00001) 

    let fit = brdf.fit(
      GgxBrdf(alpha: alpha), 
      view, 
      resolution = 128, 
      initialScale = min(1.0'f, 2.0'f * alpha)
    )

    let inverseMatrix = block:
      let m = fit.matrix.inverse
      [m[0][0], m[2][0], m[0][2], m[2][2]] / m[1][1]

    let magnitudeFresnel = [fit.magnitude, fit.fresnel]

    discard inverseMatrixFile.writeBuffer(
      addr inverseMatrix,
      sizeof(Vec4)
    )

    discard magnitudeFresnelFile.writeBuffer(
      addr magnitudeFresnel,
      sizeof(Vec2)
    )

    inc completed

    let percentage = completed.float32 / Total.float32 * 100.0'f32

    stdout.write &"\r\e[2KCompleted: {completed} / {Total} ({percentage:.2f}%)"
    stdout.flushFile()

inverseMatrixFile.close()

magnitudeFresnelFile.close()
