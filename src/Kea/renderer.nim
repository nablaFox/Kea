import 
  mesh, 
  program, 
  shader, 
  transform, 
  math, 
  primitives, 
  target,
  texture,
  std/typetraits,
  nimgl/opengl

type
  Renderable* = ref object
    mesh*: Mesh
    transform*: Transform
    topology*: Topology

  RenderItem*[M: tuple] = ref object
    drawable*: Renderable
    material*: M

  RendererObj[
    G: tuple;
    M: tuple;
    A: tuple;
  ] = object
    program: Program
    items: seq[RenderItem[M]]
    storage: MeshStorage

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
    r.program.destroy()
    r.items = @[]
    r.globalUniforms = @[]
    r.materialUniforms = @[]
    r.storage = nil

proc newFromSources[G: tuple; M: tuple; A: tuple](
  storage: MeshStorage,
  vertexSource: string,
  fragmentSource: string,
  globals: G
): Renderer[G, M, A] =
  new(result)

  result.program = program.new(vertexSource, fragmentSource)

  result.globalUniforms = result.program.uniforms[:G]
  result.materialUniforms = result.program.uniforms[:M]

  result.modelUniform = result.program.uniform("model")
  result.nmatUniform = result.program.uniform("nmat")

  result.globals = globals
  result.storage = storage

template new*[G, M, T, A](
  storage: MeshStorage,
  vert: VertShader[G, M, T],
  frag: FragShader[G, M, T, A],
  globals: G
): Renderer[G, M, A] =
  newFromSources[G, M, A](
    storage,
    vert.glsl,
    frag.glsl,
    globals
  )

template new*[G, M, T, A](
  storage: MeshStorage,
  vert: VertShader[G, M, T],
  frag: FragShader[G, M, T, A]
): Renderer[G, M, A] =
  block:
    var globals: G
    new(storage, vert, frag, globals)


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
      for name, output, attachment in fieldPairs(
        A.default,
        Atts.default
      ):
        when not compatible(typeof(output), typeof(attachment)):
          {.error: "Fragment output '" & name &
            "' is incompatible with its target attachment".}
 
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
    let drawable = item.drawable
    let model = drawable.transform.model
    let nmat = model.normalMatrix

    renderer.modelUniform.set(model)
    renderer.nmatUniform.set(nmat)

    renderer.materialUniforms.set(item.material)

    drawable.mesh.draw(topology = drawable.topology)

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  item: RenderItem[M]
): RenderItem[M] =
  renderer.items.add(item)
  item

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  mesh: Mesh,
  material = M.default,
  transform = Identity,
  topology = Triangles,
): RenderItem[M] =
  doAssert mesh != nil, "Cannot add a nil mesh"
  doAssert mesh.storage != nil, "Mesh has no storage"

  let renderable = Renderable(
    mesh: mesh,
    transform: transform,
    topology: topology
  )

  result = RenderItem[M](
    drawable: renderable,
    material: material
  )

  renderer.items.add(result)

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  mesh: Mesh,
  material = M.default,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
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

proc add*[G, M, A](
    renderer: Renderer[G, M, A],
    primitive: Primitive,
    material = M.default,
    transform = Identity,
    topology = Triangles,
): RenderItem[M] =
  renderer.add(
    primitive.mesh(renderer.storage),
    material,
    transform, 
    topology,
  )

proc add*[G, M, A](
  renderer: Renderer[G, M, A],
  primitive: Primitive,
  material = M.default,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): RenderItem[M] =
  renderer.add(
    primitive.mesh(renderer.storage),
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
  item.drawable.transform

proc position*(item: RenderItem): var Vec3 =
  item.drawable.transform.position

proc positioned*(item: RenderItem): Vec3 =
  let transform = item.drawable.transform
  transform.position

proc scale*(item: RenderItem): var Vec3 =
  item.drawable.transform.scale

proc scaled*(item: RenderItem): Vec3 =
  let transform = item.drawable.transform
  transform.scale

proc rotation*(item: RenderItem): var Mat3 =
  item.drawable.transform.rotation

proc rotated*(item: RenderItem): Mat3 =
  let transform = item.drawable.transform
  transform.rotation

proc model*(item: RenderItem): Mat4 =
  item.drawable.transform.matrix
