import
  mesh,
  program,
  shader,
  transform,
  math,
  target,
  texture,
  core,
  item,
  std/[typetraits, macros]

export item

type
  RendererObj[
    G: tuple;
    M: tuple;
    A: tuple;
  ] = object
    kea: Kea

    program: Program

    globalUniforms: seq[Uniform]
    materialUniforms: seq[Uniform]

    modelUniform: Uniform
    nmatUniform: Uniform

  Renderer*[
    G: tuple;
    M: tuple;
    A: tuple;
  ] =
    ref RendererObj[G, M, A]

  CullMode* = enum
    CullDisabled
    CullBack
    CullFront

  DepthTest* = enum
    DepthDisabled
    DepthLess
    DepthLessEqual
    DepthAlways

proc `=destroy`[G, M, A](r: var RendererObj[G, M, A]) =
  {.cast(raises: []).}:
    r.program = nil
    r.globalUniforms = @[]
    r.materialUniforms = @[]
    r.kea = nil

proc newFromSources[G: tuple; M: tuple; A: tuple](
  kea: Kea,
  vertexSource: string,
  fragmentSource: string
): Renderer[G, M, A] =
  new(result)

  result.kea = kea

  result.program = program.new(
    kea,
    vertexSource,
    fragmentSource
  )

  result.globalUniforms = result.program.uniforms[:G]
  result.materialUniforms = result.program.uniforms[:M]

  result.modelUniform = result.program.uniform("model")
  result.nmatUniform = result.program.uniform("nmat")

macro new*(
  kea: Kea,
  vert, frag: typed,
  globals: typedesc[tuple] = tuple[]
): untyped =
  let
    M = materialType(vert, frag, globals.getTypeInst[1])
    A = attachmentsType(frag)
    vs = vertGlslImpl(vert)
    fs = fragGlslImpl(vert, frag)

  result = quote do:
    newFromSources[`globals`, `M`, `A`](
      `kea`,
      `vs`,
      `fs`
    )

template compatible(Output, Attachment: typedesc): bool =
  when Attachment is Texture[R32Float]:
    Output is float32

  elif Attachment is Texture[Rg32Float]:
    Output is Vec2

  elif Attachment is Texture[Rgb32Float]:
    Output is Vec3

  elif Attachment is Texture[Rgba8Linear] or
       Attachment is Texture[Rgba8Srgb] or
       Attachment is Texture[Rgba32Float]:
    Output is Vec4

  else:
    false

proc checkAttachments(
  Outputs, Attachments: typedesc,
  index: static int = 0
) {.compileTime.} =
  when index < Outputs.tupleLen:
    when not compatible(get(Outputs, index), get(Attachments, index)):
      {.error: "Fragment output at location " & $index &
        " is incompatible with its target attachment".}

    checkAttachments(Outputs, Attachments, index + 1)

proc render*[
  G, M, A: tuple;
  Atts: tuple;
  K: static RenderTargetKind;
](
  renderer: Renderer[G, M, A],
  target: RenderTarget[K, Atts],
  items: openArray[RenderItem[M]],
  globals: G = G.default,
  cullMode: CullMode = CullDisabled,
  depthTest: DepthTest = DepthLess,
  depthWrite: bool = true
) =
  when K == BackBuffer:
    when A.tupleLen != 1:
      {.error: "Backbuffer requires exactly one fragment output".}

    elif get(A, 0) isnot Vec4:
      {.error: "Backbuffer fragment output must be Vec4".}

  elif K == DepthOnly:
    when A.tupleLen != 0:
      {.error: "A depth-only target cannot have color outputs".}

  else:
    when A.tupleLen != Atts.tupleLen:
      {.error: "Fragment output count does not match target attachment count".}

    else:
      checkAttachments(A, Atts)

  target.use()

  when K in {BackBuffer, DepthOnly, ColorDepth}:
    case depthTest
    of DepthDisabled:
      glDisable(GL_DEPTH_TEST)

    of DepthLess:
      glEnable(GL_DEPTH_TEST)
      glDepthFunc(GL_LESS)

    of DepthLessEqual:
      glEnable(GL_DEPTH_TEST)
      glDepthFunc(GL_LEQUAL)

    of DepthAlways:
      glEnable(GL_DEPTH_TEST)
      glDepthFunc(GL_ALWAYS)

    glDepthMask(depthWrite)

  case cullMode
  of CullDisabled:
    glDisable(GL_CULL_FACE)

  of CullBack:
    glEnable(GL_CULL_FACE)
    glCullFace(GL_BACK)

  of CullFront:
    glEnable(GL_CULL_FACE)
    glCullFace(GL_FRONT)

  renderer.program.use()

  renderer.globalUniforms.set(globals)

  for item in items:
    let
      renderable = item.renderable
      model = renderable.transform.model
      nmat = model.normalMatrix

    renderer.modelUniform.set(model)
    renderer.nmatUniform.set(nmat)

    renderer.materialUniforms.set(item.material)

    renderable.mesh.draw(topology = renderable.topology)

proc render*[
  G, M, A: tuple;
  Atts: tuple;
  K: static RenderTargetKind;
](
  renderer: Renderer[G, M, A],
  target: RenderTarget[K, Atts],
  item: RenderItem[M],
  globals: G = G.default,
  cullMode: CullMode = CullDisabled,
  depthTest: DepthTest = DepthLess,
  depthWrite: bool = true
) =
  renderer.render(
    target,
    [item],
    globals,
    cullMode,
    depthTest,
    depthWrite
  )
