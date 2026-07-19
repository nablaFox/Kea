# ltc fitter for ggx distribution

import std/os, std/sequtils, std/math, Kea/[math, ltc]

const
  ProjectRoot = currentSourcePath().parentDir.parentDir
  OutputDir = ProjectRoot / "src" / "Kea" / "data" / "ltc"

proc writeVectors[N: static int](
  path: string, 
  data: openArray[Vec[N]]
) =
  doAssert data.len > 0

  let file = open(path, fmWrite)
  defer: file.close()

  let byteCount = data.len * N * sizeof(float32)

  let bytesWritten = file.writeBuffer(
    addr data[0],
    byteCount,
  )

  doAssert bytesWritten == byteCount, "Failed to write all bytes to file"

proc fitAmplitude(alpha: float32, view: Vec3): Vec2 = 
  [0.0, 0.0]

proc fitMatrix(alpha: float32, view: Vec3): Vec4 = 
  # compute average light dir
  # compute X, Y, Z
  # update coefficients multiplying by X, Y, Z
  # get new coefficients wich minimize error with target brdf

  [0.0, 0.0, 0.0, 0.0]

let fitted = block:
  const N = ltc.Resolution

  var matrixTab = newSeq[Vec4](N * N)
  var amplitudeTab = newSeq[Vec2](N * N)

  for roughness in countdown(N - 1, 0):
    for view in 0 ..< N:
      let v = block:
        let x = view / (N - 1)
        let theta = min(1.57, arccos(1.0 - x^2))
        [sin(theta).float32, 0.0, cos(theta).float32]

      let a = max((roughness / (N - 1))^2, 0.00001) 

      let index = roughness + view * N

      amplitudeTab[index] = fitAmplitude(a, v)
      matrixTab[index] = fitMatrix(a, v)

  (
    matrix: matrixTab,
    amplitude: amplitudeTab
  )

createDir(OutputDir)

writeVectors(OutputDir / "matrix.bin", fitted.matrix)

writeVectors(OutputDir / "amplitude.bin", fitted.amplitude)
