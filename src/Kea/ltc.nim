const
  LutSize* = 64

  InverseMatrixData* =
    staticRead("data/ltc/inverse_matrix.rgba32f.bin")

  MagnitudeFresnelData* =
    staticRead("data/ltc/magnitude_fresnel.rg32f.bin")

static:
  doAssert InverseMatrixData.len ==
    LutSize * LutSize * 4 * sizeof(float32)

  doAssert MagnitudeFresnelData.len ==
    LutSize * LutSize * 2 * sizeof(float32)

static:
  doAssert InverseMatrixData.len ==
    LutSize * LutSize * 4 * sizeof(float32)

  doAssert MagnitudeFresnelData.len ==
    LutSize * LutSize * 2 * sizeof(float32)
