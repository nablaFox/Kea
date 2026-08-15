import nimgl/opengl

type
  TextureKind* = enum
    ColorKind
    DepthKind

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

  TextureObj[K: static TextureKind] = object
    id: GLuint
    width: int
    height: int

    when K == ColorKind:
      format: ColorFormat
    else:
      format: DepthFormat

    handle: GLuint64

  Texture*[K: static TextureKind] = ref TextureObj[K]

  ColorTexture* = Texture[ColorKind]

  DepthTexture* = Texture[DepthKind]

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

proc `=destroy`[K: static TextureKind](texture: var TextureObj[K]) =
  {.cast(raises: []).}:
    if texture.handle != 0:
      glMakeTextureHandleNonResidentARB(texture.handle)
      texture.handle = 0

    if texture.id != 0:
      glDeleteTextures(1, addr texture.id)
      texture.id = 0

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

proc createTexture[K: static TextureKind](
  data: pointer,
  width, height: Natural,
  info: TextureInfo,
  options: TextureOptions,
): Texture[K] =
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
  format: ColorFormat,
  options: TextureOptions,
): ColorTexture =
  result = createTexture[ColorKind](
    data,
    width,
    height,
    format.info,
    options,
  )

  result.format = format

proc new*(
  data: pointer,
  width, height: Natural,
  format: DepthFormat,
  options: TextureOptions,
): DepthTexture =
  result = createTexture[DepthKind](
    data,
    width,
    height,
    format.info,
    options,
  )

  result.format = format

proc new*(
  data: string,
  width, height: Natural,
  format: ColorFormat,
  options: TextureOptions,
): ColorTexture =
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
  format: DepthFormat,
  options: TextureOptions,
): DepthTexture =
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
  format: ColorFormat,
  options: TextureOptions,
): ColorTexture =
  result = new(
    nil,
    width,
    height,
    format,
    options,
  )

proc new*(
  width, height: Natural,
  format: DepthFormat,
  options: TextureOptions,
): DepthTexture =
  result = new(
    nil,
    width,
    height,
    format,
    options,
  )

proc update*[K: static TextureKind](
  texture: Texture[K],
  data: pointer,
  x, y: Natural,
  width, height: Natural
) =
  doAssert data != nil
  doAssert width > 0
  doAssert height > 0
  doAssert x + width <= texture.width
  doAssert y + height <= texture.height

  let info = texture.format.info

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

proc update*(texture: Texture, data: pointer) = 
  texture.update(data, 0, 0, texture.width, texture.height)

proc update*(
  texture: ColorTexture,
  data: openArray[float32]
) = 
  let components = 
    case texture.format
    of R32Float:
      1
    of Rg32Float:
      2
    of Rgb32Float:
      3
    of Rgba32Float:
      4
    else:
      doAssert false, "Unsupported color format for float32 data"
      0

  echo "ok"

  doAssert data.len == texture.width * texture.height * components,
    "Texture data size does not match texture dimensions"

  if data.len > 0:
     texture.update(addr data[0])

proc id*[K: static TextureKind](
  texture: Texture[K],
): GLuint =
  texture.id

proc width*[K: static TextureKind](
  texture: Texture[K],
): int =
  texture.width

proc height*[K: static TextureKind](
  texture: Texture[K],
): int =
  texture.height

proc format*(texture: ColorTexture): ColorFormat =
  texture.format

proc format*(texture: DepthTexture): DepthFormat =
  texture.format

proc residentHandle*[K: static TextureKind](
  texture: Texture[K],
): GLuint64 =
  doAssert texture != nil

  if texture.handle == 0:
    texture.handle =
      glGetTextureHandleARB(texture.id)

    doAssert texture.handle != 0,
      "Failed to create bindless texture handle"

    glMakeTextureHandleResidentARB(texture.handle)

  result = texture.handle
