import std/os, nimgl/opengl, texture

type LtcTextures* = object
  matrix*: Texture
  amplitude*: Texture

const
  MatrixUnit* = 0
  AmplitudeUnit* = 1

  DataDir = currentSourcePath().parentDir / "data" / "ltc"

  BytesPerTexel = 4 * sizeof(float32)

  MatrixData = staticRead(DataDir / "matrix.bin")
  AmplitudeData = staticRead(DataDir / "amplitude.bin")

  MatrixTexels = MatrixData.len div BytesPerTexel
  AmplitudeTexels = AmplitudeData.len div BytesPerTexel

  Resolution = block:
    var side = 0

    while (side + 1) * (side + 1) <= MatrixTexels:
      inc side

    doAssert side * side == MatrixTexels,
      "LTC texture data must contain a square number of texels"

    side

static:
  doAssert MatrixData.len mod BytesPerTexel == 0
  doAssert AmplitudeData.len mod BytesPerTexel == 0
  doAssert MatrixTexels == AmplitudeTexels

proc new*(): LtcTextures =
  const options = TextureOptions(
    minFilter: GL_LINEAR,
    magFilter: GL_LINEAR,
    wrapS: GL_CLAMP_TO_EDGE,
    wrapT: GL_CLAMP_TO_EDGE
  )

  result.matrix = texture.new(
    MatrixData,
    Resolution,
    Resolution,
    Rgba32Float,
    options
  )

  result.amplitude = texture.new(
    AmplitudeData,
    Resolution,
    Resolution,
    Rgba32Float,
    options
  )

proc bindTextures*(textures: LtcTextures) =
  textures.matrix.bindAt(MatrixUnit)
  textures.amplitude.bindAt(AmplitudeUnit)

proc destroy*(textures: LtcTextures) =
  let matrixId = textures.matrix.id
  let amplitudeId = textures.amplitude.id

  glDeleteTextures(1, addr matrixId)
  glDeleteTextures(1, addr amplitudeId)
