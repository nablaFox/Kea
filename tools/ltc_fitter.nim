import std/os, std/sequtils

const
  ProjectRoot = currentSourcePath().parentDir.parentDir
  OutputDir = ProjectRoot / "src" / "Kea" / "data" / "ltc"
  LtcResolution = 64

proc writeFloats(path: string, data: openArray[float32]) =
  let file = open(path, fmWrite)
  defer: file.close()

  doAssert data.len > 0

  let bytesWritten = file.writeBuffer(
    addr data[0],
    data.len * sizeof(float32)
  )

  doAssert bytesWritten == data.len * sizeof(float32)

createDir(OutputDir)

writeFloats(OutputDir / "matrix.bin", repeat(0.0'f32, LtcResolution))

writeFloats(OutputDir / "amplitude.bin", repeat(0.0'f32, LtcResolution))
