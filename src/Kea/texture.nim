import nimgl/opengl

type
  TextureFormat* = enum
    Rgba8Linear
    Rgba8Srgb
    Rgba32Float

  TextureOptions* = object
    minFilter*: GLenum
    magFilter*: GLenum
    wrapS*: GLenum
    wrapT*: GLenum

  Texture* = ref object
    id: GLuint
    width: int
    height: int

proc info(format: TextureFormat): tuple[
  internalFormat: GLint,
  sourceFormat: GLenum,
  sourceType: GLenum
] =
  case format
  of Rgba8Linear:
    (
      internalFormat: GL_RGBA8.GLint,
      sourceFormat: GL_RGBA,
      sourceType: GL_UNSIGNED_BYTE
    )

  of Rgba8Srgb:
    (
      internalFormat: GL_SRGB8_ALPHA8.GLint,
      sourceFormat: GL_RGBA,
      sourceType: GL_UNSIGNED_BYTE
    )

  of Rgba32Float:
    (
      internalFormat: GL_RGBA32F.GLint,
      sourceFormat: GL_RGBA,
      sourceType: EGL_FLOAT
    )

proc new*(
  data: pointer, 
  width: Natural, 
  height: Natural,
  format: TextureFormat,
  options: TextureOptions
): Texture =
  assert width > 0
  assert height > 0

  let info = format.info

  new(result)

  result.width = int(width)
  result.height = int(height)

  glGenTextures(1, addr result.id)
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

proc new*(
  data: string,
  width: Natural,
  height: Natural,
  format: TextureFormat,
  options: TextureOptions,
): Texture = 
  assert data.len > 0

  new(
    cast[pointer](addr data[0]),
    width,
    height,
    format,
    options,
  )

proc id*(texture: Texture): GLuint =
  texture.id

proc width*(texture: Texture): int =
  texture.width

proc height*(texture: Texture): int =
  texture.height

proc bindAt*(texture: Texture, unit: Natural) =
  glActiveTexture((GL_TEXTURE0.uint32 + unit.uint32).GLenum)
  glBindTexture(GL_TEXTURE_2D, texture.id)  
