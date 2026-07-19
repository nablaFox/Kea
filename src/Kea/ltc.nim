import std/os, std/math, nimgl/opengl, texture

type LtcTextures* = object
  matrix*: Texture
  amplitude*: Texture

const
  MatrixUnit* = 0
  AmplitudeUnit* = 1

  Resolution* = 64

  DataDir = currentSourcePath().parentDir / "data" / "ltc"

  MatrixTab = staticRead(DataDir / "matrix.bin")
  AmplitudeTab = staticRead(DataDir / "amplitude.bin")

static:
  doAssert MatrixTab.len == Resolution * Resolution * 4 * sizeof(float32)
  doAssert AmplitudeTab.len == Resolution * Resolution * 2 * sizeof(float32)

proc new*(): LtcTextures =
  const options = TextureOptions(
    minFilter: GL_LINEAR,
    magFilter: GL_LINEAR,
    wrapS: GL_CLAMP_TO_EDGE,
    wrapT: GL_CLAMP_TO_EDGE
  )

  result.matrix = texture.new(
    MatrixTab,
    Resolution,
    Resolution,
    Rgba32Float,
    options
  )

  result.amplitude = texture.new(
    AmplitudeTab,
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
