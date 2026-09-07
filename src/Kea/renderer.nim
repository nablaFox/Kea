import 
  mesh, 
  program, 
  shader, 
  transform, 
  math, 
  target,
  texture,
  core,
  std/[typetraits, macros]

type
  Renderable* = ref object
    mesh*: Mesh
    transform*: Transform

  RenderItem*[M: tuple] = ref object
    renderable*: Renderable
    topology*: Topology
    material*: M

  RendererObj[
    G: tuple;
    M: tuple;
    A: tuple;
  ] = object
    kea: Kea

    program: Program
    items: seq[RenderItem[M]]

    globalUniforms: seq[Uniform]
    materialUniforms: seq[Uniform]

    modelUniform: Uniform
    nmatUniform: Uniform

    globals*: G

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

{.experimental: "dotOperators".}

template `.`*[G, M, A](r: Renderer[G, M, A], field: untyped): untyped =
  r.globals.field

template `.=`*[G, M, A](r: Renderer[G, M, A], field: untyped, value: untyped) =
  r.globals.field = value

proc `=destroy`[G, M, A](r: var RendererObj[G, M, A]) =
  {.cast(raises: []).}:
    r.program = nil
    r.items = @[]
    r.globalUniforms = @[]
    r.materialUniforms = @[]
    reset r.globals
    r.kea = nil

proc newFromSources[G: tuple; M: tuple; A: tuple](
  kea: Kea,
  vertexSource: string,
  fragmentSource: string,
  globals: G
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

  result.globals = globals

macro new*[G: tuple](
  kea: Kea,
  vert, frag: typed,
  globals: G = ()
): untyped =
  let 
    M = materialType(vert, frag, globals)
    A = attachmentsType(frag)
    vs = vertGlslImpl(vert)
    fs = fragGlslImpl(vert, frag)

  result = quote do:
    newFromSources[typeof(`globals`), `M`, `A`](
      `kea`,
      `vs`,
      `fs`,
      `globals`
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
  cullMode: CullMode = CullBack,
  depthTest: DepthTest = DepthLess,
  depthWrite: bool = true,
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
      static:
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

  renderer.globalUniforms.set(renderer.globals)

  for item in renderer.items:
    let renderable = item.renderable
    let model = renderable.transform.model
    let nmat = model.normalMatrix

    renderer.modelUniform.set(model)
    renderer.nmatUniform.set(nmat)

    renderer.materialUniforms.set(item.material)

    renderable.mesh.draw(topology = item.topology)

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  item: RenderItem[M]
): RenderItem[M] =
  renderer.items.add(item)
  item

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  mesh: Mesh,
  material: M = M.default,
  transform: Transform,
  topology = Triangles,
): RenderItem[M] =
  doAssert mesh != nil, "Cannot add a nil mesh"

  let renderable = Renderable(
    mesh: mesh,
    transform: transform
  )

  result = RenderItem[M](
    renderable: renderable,
    material: material,
    topology: topology
  )

  renderer.items.add(result)

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  mesh: Mesh,
  material: M = M.default,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  topology = Triangles,
): RenderItem[M] =
  renderer.add(
    mesh,
    material,
    transform.new(
      x = x,
      y = y,
      z = z,
      pitch = pitch,
      yaw = yaw,
      roll = roll,
      scale = scale
    ),
    topology,
  )

proc transform*(item: RenderItem): var Transform =
  item.renderable.transform

proc position*(item: RenderItem): var Vec3 =
  item.renderable.transform.position

proc positioned*(item: RenderItem): Vec3 =
  let transform = item.renderable.transform
  transform.position

proc scale*(item: RenderItem): var Vec3 =
  item.renderable.transform.scale

proc scaled*(item: RenderItem): Vec3 =
  let transform = item.renderable.transform
  transform.scale

proc rotation*(item: RenderItem): var Mat3 =
  item.renderable.transform.rotation

proc rotated*(item: RenderItem): Mat3 =
  let transform = item.renderable.transform
  transform.rotation

proc model*(item: RenderItem): Mat4 =
  item.renderable.transform.model
