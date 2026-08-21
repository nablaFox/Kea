import nimgl/opengl

type
  TextureOptions* = object
    minFilter*: GLenum
    magFilter*: GLenum
    wrapS*: GLenum
    wrapT*: GLenum

  TextureInfo = tuple[
    internalFormat: GLint,
    sourceFormat: GLenum,
    sourceType: GLenum,
  ]

  TextureFormat* = enum
    Rgba8Linear
    Rgba8Srgb
    R32Float
    Rg32Float
    Rgb32Float
    Rgba32Float
    Depth24
    Depth32Float 

  TextureObj[F: static TextureFormat] = object
    id: GLuint
    width: int
    height: int
    sampleHandle: GLuint64

    when F in {Rgba8Linear, R32Float, Rg32Float, Rgba32Float}:
      imageHandle: GLuint64

  Texture*[F: static TextureFormat] =
    ref TextureObj[F]

const
  DataTextureOptions* = TextureOptions(
    minFilter: GL_NEAREST,
    magFilter: GL_NEAREST,
    wrapS: GL_CLAMP_TO_EDGE,
    wrapT: GL_CLAMP_TO_EDGE,
  )

  LinearTextureOptions* = TextureOptions(
    minFilter: GL_LINEAR,
    magFilter: GL_LINEAR,
    wrapS: GL_CLAMP_TO_EDGE,
    wrapT: GL_CLAMP_TO_EDGE,
  )

proc `=destroy`[F: static TextureFormat](texture: var TextureObj[F]) =
  {.cast(raises: []).}:
    if texture.sampleHandle != 0:
      glMakeTextureHandleNonResidentARB(texture.sampleHandle)
      texture.sampleHandle = 0

    when F in {Rgba8Linear, R32Float, Rg32Float, Rgba32Float}:
      if texture.imageHandle != 0:
        glMakeImageHandleNonResidentARB(texture.imageHandle)
        texture.imageHandle = 0

    if texture.id != 0:
      glDeleteTextures(1, addr texture.id)
      texture.id = 0

proc GLenum(format: TextureFormat): GLenum =
  case format
  of Rgba8Linear:
    GL_RGBA8

  of Rgba8Srgb:
    GL_SRGB8_ALPHA8

  of R32Float:
    GL_R32F

  of Rg32Float:
    GL_RG32F

  of Rgb32Float:
    GL_RGB32F

  of Rgba32Float:
    GL_RGBA32F

  of Depth24:
    GL_DEPTH_COMPONENT24

  of Depth32Float:
    GL_DEPTH_COMPONENT32F

proc components(format: TextureFormat): int =
  case format
  of Rgba8Linear, Rgba8Srgb, Rgba32Float:
    4
  of R32Float:
    1
  of Rg32Float:
    2
  of Rgb32Float:
    3
  of Depth24, Depth32Float:
    1

proc info(format: TextureFormat): TextureInfo =
  case format
  of Rgba8Linear:
    result = (
      internalFormat: GL_RGBA8.GLint,
      sourceFormat: GL_RGBA,
      sourceType: GL_UNSIGNED_BYTE,
    )

  of Rgba8Srgb:
    result = (
      internalFormat: GL_SRGB8_ALPHA8.GLint,
      sourceFormat: GL_RGBA,
      sourceType: GL_UNSIGNED_BYTE,
    )

  of R32Float:
    result = (
      internalFormat: GL_R32F.GLint,
      sourceFormat: GL_RED,
      sourceType: EGL_FLOAT,
    )

  of Rg32Float:
    result = (
      internalFormat: GL_RG32F.GLint,
      sourceFormat: GL_RG,
      sourceType: EGL_FLOAT,
    )

  of Rgb32Float:
    result = (
      internalFormat: GL_RGB32F.GLint,
      sourceFormat: GL_RGB,
      sourceType: EGL_FLOAT,
    )

  of Rgba32Float:
    result = (
      internalFormat: GL_RGBA32F.GLint,
      sourceFormat: GL_RGBA,
      sourceType: EGL_FLOAT,
    )

  of Depth24:
    result = (
      internalFormat: GL_DEPTH_COMPONENT24.GLint,
      sourceFormat: GL_DEPTH_COMPONENT,
      sourceType: GL_UNSIGNED_INT,
    )

  of Depth32Float:
    result = (
      internalFormat: GL_DEPTH_COMPONENT32F.GLint,
      sourceFormat: GL_DEPTH_COMPONENT,
      sourceType: EGL_FLOAT,
    )

proc createTexture[F: static TextureFormat](
  data: pointer,
  width, height: Natural,
  info: TextureInfo,
  options: TextureOptions,
): Texture[F] =
  doAssert width > 0
  doAssert height > 0

  system.new(result)

  result.width = width.int
  result.height = height.int

  var previousTexture: GLint

  glGetIntegerv(
    GL_TEXTURE_BINDING_2D,
    addr previousTexture,
  )

  glGenTextures(1, addr result.id)

  doAssert result.id != 0,
    "Failed to create OpenGL texture"

  glBindTexture(GL_TEXTURE_2D, result.id)

  glTexParameteri(
    GL_TEXTURE_2D,
    GL_TEXTURE_MIN_FILTER,
    options.minFilter.GLint,
  )

  glTexParameteri(
    GL_TEXTURE_2D,
    GL_TEXTURE_MAG_FILTER,
    options.magFilter.GLint,
  )

  glTexParameteri(
    GL_TEXTURE_2D,
    GL_TEXTURE_WRAP_S,
    options.wrapS.GLint,
  )

  glTexParameteri(
    GL_TEXTURE_2D,
    GL_TEXTURE_WRAP_T,
    options.wrapT.GLint,
  )

  glTexImage2D(
    GL_TEXTURE_2D,
    0,
    info.internalFormat,
    width.GLsizei,
    height.GLsizei,
    0,
    info.sourceFormat,
    info.sourceType,
    data,
  )

  glBindTexture(
    GL_TEXTURE_2D,
    previousTexture.GLuint,
  )

template new*(
  data: pointer,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): untyped =
  createTexture[format](
    data,
    width,
    height,
    format.info,
    options,
  )

proc new*(
  data: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  doAssert data.len > 0

  result = createTexture[format](
    addr data[0],
    width,
    height,
    format.info,
    options
  )

template new*(
  width, height: Natural,
  format: untyped,
  options: TextureOptions,
): untyped =
  createTexture[format](
    nil,
    width,
    height,
    format.info,
    options,
  )

proc update*[F: static TextureFormat](
  texture: Texture[F],
  data: pointer,
  x, y: Natural,
  width, height: Natural
) =
  doAssert data != nil
  doAssert width > 0
  doAssert height > 0
  doAssert x + width <= texture.width
  doAssert y + height <= texture.height

  let info = info(F)

  var previousTexture: GLint

  glGetIntegerv(
    GL_TEXTURE_BINDING_2D,
    addr previousTexture,
  )

  glBindTexture(
    GL_TEXTURE_2D,
    texture.id,
  )

  glTexSubImage2D(
    GL_TEXTURE_2D,
    0,
    x.GLint,
    y.GLint,
    width.GLsizei,
    height.GLsizei,
    info.sourceFormat,
    info.sourceType,
    data,
  )

  glBindTexture(
    GL_TEXTURE_2D,
    previousTexture.GLuint,
  )

proc update*[F: static TextureFormat](
  texture: Texture[F],
  data: pointer
) = 
  texture.update(
    data,
    0,
    0,
    texture.width,
    texture.height,
  )

proc update*[F: static TextureFormat](
  texture: Texture[F],
  data: openArray[float32]
) = 
  when F notin {R32Float, Rg32Float, Rgb32Float, Rgba32Float}:
    {.error: "Unsupported color format for float32 data".}

  doAssert data.len == texture.width * texture.height * F.components,
    "Texture data size does not match texture dimensions"

  if data.len > 0:
    texture.update(addr data[0])

proc id*[F](texture: Texture[F]): GLuint =
  texture.id

proc width*[F](texture: Texture[F]): int =
  texture.width

proc height*[F](texture: Texture[F]): int =
  texture.height

proc size*[F](texture: Texture[F]): array[2, float32] =
  [texture.width.float32, texture.height.float32]

proc sample*(
  texture: Texture[Rgba8Linear],
  sample: array[2, float32]
): array[4, float32] =
  discard

proc sample*(
  texture: Texture[Rgba8Srgb],
  sample: array[2, float32]
): array[4, float32] =
  discard

proc sample*(
  texture: Texture[R32Float],
  sample: array[2, float32]
): array[1, float32] =
  discard

proc sample*(
  texture: Texture[Rg32Float],
  sample: array[2, float32]
): array[2, float32] =
  discard

proc sample*(
  texture: Texture[Rgb32Float],
  sample: array[2, float32]
): array[3, float32] =
  discard

proc sample*(
  texture: Texture[Rgba32Float],
  sample: array[2, float32]
): array[4, float32] =
  discard

proc residentSampleHandle*[F: static TextureFormat](
  texture: Texture[F]
): GLuint64 =
  doAssert texture != nil

  if texture.sampleHandle == 0:
    texture.sampleHandle =
      glGetTextureHandleARB(texture.id)

    doAssert texture.sampleHandle != 0,
      "Failed to create bindless texture handle"

    glMakeTextureHandleResidentARB(texture.sampleHandle)

  result = texture.sampleHandle

proc residentImageHandle*[F: static TextureFormat](
  texture: Texture[F]
): GLuint64 =
  doAssert texture != nil

  when F notin {Rgba8Linear, R32Float, Rg32Float, Rgba32Float}:
    {.error: "Unsupported format for image2D".}

  if texture.imageHandle == 0:
    texture.imageHandle = glGetImageHandleARB(
      texture.id,
      0,                   # mip level
      false,               # not layered
      0,                   # layer
      F.GLenum,
    )

    doAssert texture.imageHandle != 0,
      "Failed to create bindless image handle"

    glMakeImageHandleResidentARB(
      texture.imageHandle,
      GL_READ_WRITE,
    )

  result = texture.imageHandle
