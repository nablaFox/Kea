import nimgl/opengl

type
  ColorFormat* = enum
    Rgba8Linear
    Rgba8Srgb
    R32Float
    Rg32Float
    Rgb32Float
    Rgba32Float

  DepthFormat* = enum
    Depth24
    Depth32Float

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

  TextureFormat = ColorFormat | DepthFormat

  TextureObj[F: static; FT = typeof(F)] = object
    id: GLuint
    width: int
    height: int
    sampleHandle: GLuint64
    imageHandle: GLuint64

  Texture*[F: static] =
    ref TextureObj[F]

  ColorTexture*[F: static ColorFormat] =
    Texture[F]

  DepthTexture*[F: static DepthFormat] =
    Texture[F]

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

proc `=destroy`[F: static; FT](
  texture: var TextureObj[F, FT]
) =
  {.cast(raises: []).}:
    if texture.sampleHandle != 0:
      glMakeTextureHandleNonResidentARB(texture.sampleHandle)
      texture.sampleHandle = 0

    if texture.imageHandle != 0:
      glMakeImageHandleNonResidentARB(texture.imageHandle)
      texture.imageHandle = 0

    if texture.id != 0:
      glDeleteTextures(1, addr texture.id)
      texture.id = 0

proc GLenum(format: ColorFormat): GLenum =
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

proc GLenum(format: DepthFormat): GLenum =
  case format
  of Depth24:
    GL_DEPTH_COMPONENT24

  of Depth32Float:
    GL_DEPTH_COMPONENT32F

proc components(format: ColorFormat): int =
  case format
  of Rgba8Linear, Rgba8Srgb, Rgba32Float:
    4
  of R32Float:
    1
  of Rg32Float:
    2
  of Rgb32Float:
    3

proc info(format: ColorFormat): TextureInfo =
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

proc info(format: DepthFormat): TextureInfo =
  case format
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

proc createTexture[F: static](
  data: pointer,
  width, height: Natural,
  info: TextureInfo,
  options: TextureOptions,
): Texture[F] =
  doAssert width > 0
  doAssert height > 0

  new(result)

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

proc new*(
  data: pointer,
  width, height: Natural,
  format: static ColorFormat,
  options: TextureOptions,
): ColorTexture[format] =
  result = createTexture[format](
    data,
    width,
    height,
    format.info,
    options,
  )

proc new*(
  data: pointer,
  width, height: Natural,
  format: static DepthFormat,
  options: TextureOptions,
): DepthTexture[format] =
  result = createTexture[format](
    data,
    width,
    height,
    format.info,
    options,
  )

proc new*(
  data: string,
  width, height: Natural,
  format: static ColorFormat,
  options: TextureOptions,
): ColorTexture[format] =
  doAssert data.len > 0

  result = new(
    addr data[0],
    width,
    height,
    format,
    options,
  )

proc new*(
  data: string,
  width, height: Natural,
  format: static DepthFormat,
  options: TextureOptions,
): DepthTexture[format] =
  doAssert data.len > 0

  result = new(
    addr data[0],
    width,
    height,
    format,
    options,
  )

proc new*(
  width, height: Natural,
  format: static ColorFormat,
  options: TextureOptions,
): ColorTexture[format] =
  result = new(
    nil,
    width,
    height,
    format,
    options,
  )

proc new*(
  width, height: Natural,
  format: static DepthFormat,
  options: TextureOptions,
): DepthTexture[format] =
  result = new(
    nil,
    width,
    height,
    format,
    options,
  )

proc update*[F](
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

proc update*[F](
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

proc update*[F: static ColorFormat](
  texture: ColorTexture[F],
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

proc residentSampleHandle*[F: static](
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

proc residentImageHandle*[F: static ColorFormat](
  texture: ColorTexture[F]
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
