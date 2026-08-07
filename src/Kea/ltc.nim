import std/os

const
  LutSize* = 64

  DataDir = currentSourcePath().parentDir / "data" / "ltc"

  InverseMatrixData* =
    staticRead(DataDir / "inverse_matrix.rgba32f.bin")

  MagnitudeFresnelData* =
    staticRead(DataDir / "magnitude_fresnel.rg32f.bin")

static:
  doAssert InverseMatrixData.len ==
    LutSize * LutSize * 4 * sizeof(float32)

  doAssert MagnitudeFresnelData.len ==
    LutSize * LutSize * 2 * sizeof(float32)
