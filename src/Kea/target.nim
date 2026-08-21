import nimgl/opengl, std/typetraits, texture, colors

type
  RenderTargetKind* = enum
    BackBuffer
    ColorOnly
    DepthOnly
    ColorDepth

  RenderTargetObj*[
    K: static RenderTargetKind;
    A: tuple;
  ] = object
    framebuffer: GLuint

    width, height: int32

    when K in {ColorOnly, ColorDepth}:
      attachments*: A

    when K in {DepthOnly, ColorDepth}:
      depth*: Texture[Depth24]

  RenderTarget*[
    K: static RenderTargetKind;
    A: tuple;
  ] =
    ref RenderTargetObj[K, A]

  ColorAtt* = tuple[
    color: Texture[Rgba8Linear]
  ]

  BackBufferTarget* =
    RenderTarget[BackBuffer, tuple[]]

  ColorTarget*[A = ColorAtt] =
    RenderTarget[ColorOnly, A]

  ColorDepthTarget*[A = ColorAtt] =
    RenderTarget[ColorDepth, A]

  DepthTarget* =
    RenderTarget[DepthOnly, tuple[]]

proc `=destroy`[
  K: static RenderTargetKind;
  A: tuple;
](
  target: var RenderTargetObj[K, A]
) =
  {.cast(raises: []).}:
    if target.framebuffer != 0:
      glDeleteFramebuffers(1, addr target.framebuffer)
      target.framebuffer = 0

    when K in {ColorOnly, ColorDepth}:
      reset target.attachments

    when K in {DepthOnly, ColorDepth}:
      target.depth = nil

template checkColorAttachment[F: static TextureFormat](
  attachment: Texture[F]
) =
  when F notin {
    Rgba8Linear,
    Rgba8Srgb,
    R32Float,
    Rg32Float,
    Rgb32Float,
    Rgba32Float
  }:
    {.error: "Texture format is not a color format".}

proc checkedSize[A: tuple](attachments: A): tuple[width, height: int] =
  when A.tupleLen == 0:
    {.error: "A color target must have at least one attachment".}

  var first = true

  for name, attachment in attachments.fieldPairs:
    checkColorAttachment(attachment)

    doAssert attachment != nil,
      "Color attachment '" & name & "' is nil"

    if first:
      result = (attachment.width, attachment.height)
      first = false
    else:
      doAssert attachment.width == result.width,
        "Color attachments have different widths"

      doAssert attachment.height == result.height,
        "Color attachments have different heights"

proc initializeFramebuffer[
  K: static RenderTargetKind;
  A: tuple;
](target: RenderTarget[K, A]) =
  glGenFramebuffers(
    1,
    addr target.framebuffer,
  )

  doAssert target.framebuffer != 0, "Failed to create framebuffer"

  glBindFramebuffer(
    GL_FRAMEBUFFER,
    target.framebuffer,
  )

  when K in {ColorOnly, ColorDepth}:
    const N = A.tupleLen

    when N == 0:
      {.error: "A color target must have at least one attachment".}

    var drawBuffers: array[N, GLenum]
    var index = 0

    for attachment in fields(target.attachments):
      let colorAttachment = (GL_COLOR_ATTACHMENT0.uint32 + index.uint32).GLenum

      glFramebufferTexture2D(
        GL_FRAMEBUFFER,
        colorAttachment,
        GL_TEXTURE_2D,
        attachment.id,
        0
      )

      drawBuffers[index] = colorAttachment
      inc index

    glDrawBuffers(
      N.GLsizei,
      addr drawBuffers[0]
    )

    glReadBuffer(GL_COLOR_ATTACHMENT0)

  else:
    glDrawBuffer(GL_NONE)
    glReadBuffer(GL_NONE)

  when K in {DepthOnly, ColorDepth}:
    glFramebufferTexture2D(
      GL_FRAMEBUFFER,
      GL_DEPTH_ATTACHMENT,
      GL_TEXTURE_2D,
      target.depth.id,
      0
    )

  let status =
    glCheckFramebufferStatus(GL_FRAMEBUFFER)

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  doAssert status == GL_FRAMEBUFFER_COMPLETE,
    "Framebuffer is incomplete: " & $(status.uint32)

proc new*(width, height: int32): BackBufferTarget =
  doAssert width >= 0
  doAssert height >= 0

  system.new(result)

  result.framebuffer = 0
  result.width = width
  result.height = height

proc new*[A: tuple](attachments: A): ColorTarget[A] =
  let size = attachments.checkedSize

  system.new(result)

  result.width = size.width.int32
  result.height = size.height.int32
  result.attachments = attachments

  initializeFramebuffer[ColorOnly, A](result)

proc new*[F: static TextureFormat](
  attachment: Texture[F]
): ColorTarget[tuple[color: Texture[F]]] =
  new((color: attachment))

proc new*(depth: Texture[Depth24]): DepthTarget =
  doAssert depth != nil

  system.new(result)

  result.width = depth.width.int32
  result.height = depth.height.int32
  result.depth = depth

  initializeFramebuffer[DepthOnly, tuple[]](result)

proc new*[A: tuple](
  attachments: A,
  depth: Texture[Depth24],
): ColorDepthTarget[A] =
  let size = attachments.checkedSize

  doAssert depth != nil

  doAssert size.width == depth.width,
    "Color and depth attachments have different widths"

  doAssert size.height == depth.height,
    "Color and depth attachments have different heights"

  system.new(result)

  result.width = size.width.int32
  result.height = size.height.int32
  result.attachments = attachments
  result.depth = depth

  initializeFramebuffer[ColorDepth, A](result)

proc new*[F: static TextureFormat](
  attachment: Texture[F],
  depth: Texture[Depth24]
): ColorDepthTarget[tuple[color: Texture[F]]] =
  new((color: attachment), depth)

proc resize*(
  target: BackBufferTarget,
  width, height: int32
) =
  doAssert width >= 0
  doAssert height >= 0

  target.width = width
  target.height = height

proc use*[
  K: static RenderTargetKind;
  A: tuple;
](target: RenderTarget[K, A]) =
  glBindFramebuffer(GL_FRAMEBUFFER, target.framebuffer)
  glViewport(0, 0, target.width, target.height)

proc clear*[
  K: static RenderTargetKind;
  A: tuple;
](
  target: RenderTarget[K, A],
  color: Color = Black,
  depth = 1.0'f
) =
  target.use()

  when K in {BackBuffer, ColorDepth}:
    glClearColor(color.r, color.g, color.b, 1.0'f)
    glClearDepth(depth.GLdouble)

    glClear(
      GL_COLOR_BUFFER_BIT or
      GL_DEPTH_BUFFER_BIT
    )

  elif K is ColorOnly:
    glClearColor(color.r, color.g, color.b, 1.0'f)
    glClear(GL_COLOR_BUFFER_BIT)

  elif K is DepthOnly:
    glClearDepth(depth.GLdouble)
    glClear(GL_DEPTH_BUFFER_BIT)

proc aspect*[
  K: static RenderTargetKind;
  A: tuple;
](target: RenderTarget[K, A]): float32 =
  if target.height == 0:
    return 1.0'f

  return target.width.float32 / target.height.float32

template attachment*[A: tuple](
  target: ColorTarget[A],
  index: static int
): untyped =
  target.attachments[index]

template attachment*[A: tuple](
  target: ColorDepthTarget[A],
  index: static int
): untyped =
  target.attachments[index]

proc depth*(target: DepthTarget): Texture[Depth24] =
  target.depth

proc depth*[A: tuple](target: ColorDepthTarget[A]): Texture[Depth24] =
  target.depth
