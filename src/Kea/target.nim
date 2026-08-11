import nimgl/opengl, texture, colors

type
  RenderTargetKind* = enum
    BackBuffer
    ColorOnly
    DepthOnly
    ColorDepth

  RenderTargetObj*[K: static RenderTargetKind] = object
    framebuffer: GLuint

    width: int32
    height: int32

    when K == ColorOnly or K == ColorDepth:
      color: ColorTexture

    when K == DepthOnly or K == ColorDepth:
      depth: DepthTexture

  RenderTarget*[K: static RenderTargetKind] =
    ref RenderTargetObj[K]

proc `=destroy`[K: static RenderTargetKind](
  target: var RenderTargetObj[K],
) =
  {.cast(raises: []).}:
    if target.framebuffer != 0:
      glDeleteFramebuffers(1, addr target.framebuffer)

      target.framebuffer = 0

    when K == ColorOnly or K == ColorDepth:
      target.color = nil

    when K == DepthOnly or K == ColorDepth:
      target.depth = nil

proc initializeFramebuffer[
  K: static RenderTargetKind
](target: RenderTarget[K]) =
  glGenFramebuffers(
    1,
    addr target.framebuffer,
  )

  doAssert target.framebuffer != 0,
    "Failed to create framebuffer"

  glBindFramebuffer(
    GL_FRAMEBUFFER,
    target.framebuffer,
  )

  when K == ColorOnly or K == ColorDepth:
    glFramebufferTexture2D(
      GL_FRAMEBUFFER,
      GL_COLOR_ATTACHMENT0,
      GL_TEXTURE_2D,
      target.color.id,
      0,
    )

    glDrawBuffer(GL_COLOR_ATTACHMENT0)
    glReadBuffer(GL_COLOR_ATTACHMENT0)

  else:
    glDrawBuffer(GL_NONE)
    glReadBuffer(GL_NONE)

  when K == DepthOnly or K == ColorDepth:
    glFramebufferTexture2D(
      GL_FRAMEBUFFER,
      GL_DEPTH_ATTACHMENT,
      GL_TEXTURE_2D,
      target.depth.id,
      0,
    )

  let status =
    glCheckFramebufferStatus(GL_FRAMEBUFFER)

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  doAssert status == GL_FRAMEBUFFER_COMPLETE,
    "Framebuffer is incomplete: " & $(status.uint32)

proc new*(
  width, height: int32,
): RenderTarget[BackBuffer] =
  doAssert width >= 0
  doAssert height >= 0

  new(result)

  result.framebuffer = 0
  result.width = width
  result.height = height

proc new*(
  color: ColorTexture,
): RenderTarget[ColorOnly] =
  doAssert color != nil

  new(result)

  result.width = color.width.int32
  result.height = color.height.int32
  result.color = color

  result.initializeFramebuffer()

proc new*(
  depth: DepthTexture,
): RenderTarget[DepthOnly] =
  doAssert depth != nil

  new(result)

  result.width = depth.width.int32
  result.height = depth.height.int32
  result.depth = depth

  result.initializeFramebuffer()

proc new*(
  color: ColorTexture,
  depth: DepthTexture,
): RenderTarget[ColorDepth] =
  doAssert color != nil
  doAssert depth != nil

  doAssert color.width == depth.width,
    "Color and depth attachments have different widths"

  doAssert color.height == depth.height,
    "Color and depth attachments have different heights"

  new(result)

  result.width = color.width.int32
  result.height = color.height.int32
  result.color = color
  result.depth = depth

  result.initializeFramebuffer()

proc resize*(
  target: RenderTarget[BackBuffer],
  width, height: int32,
) =
  doAssert width >= 0
  doAssert height >= 0

  target.width = width
  target.height = height

proc use*[K: static RenderTargetKind](target: RenderTarget[K]) =
  glBindFramebuffer(GL_FRAMEBUFFER, target.framebuffer)
  glViewport(0, 0, target.width, target.height)

proc clear*[K: static RenderTargetKind](
  target: RenderTarget[K],
  color: Color = Black,
  depth = 1.0'f,
) =
  target.use()

  when K == BackBuffer or K == ColorDepth:
    glClearColor(color.r, color.g, color.b, 1.0'f)
    glClearDepth(depth.GLdouble)

    glClear(
      GL_COLOR_BUFFER_BIT or
      GL_DEPTH_BUFFER_BIT
    )

  elif K == ColorOnly:
    glClearColor(color.r, color.g, color.b, 1.0'f)
    glClear(GL_COLOR_BUFFER_BIT)

  elif K == DepthOnly:
    glClearDepth(depth.GLdouble)
    glClear(GL_DEPTH_BUFFER_BIT)

proc aspect*[K: static RenderTargetKind](target: RenderTarget[K]): float32 =
  if target.height == 0:
    return 1.0'f

  return target.width.float32 / target.height.float32
