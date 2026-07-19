import 
  renderer,
  camera,
  colors,
  mesh,
  input,
  pbr,
  ltc,
  nimgl/[glfw, opengl]

const
  DefaultVertexCapacity {.intdefine: "kea.vertexCapacity".} = 1_000_000
  DefaultIndexCapacity {.intdefine: "kea.indexCapacity".} = 1_000_000

type
  Frame* = object
    delta*: float32
    fps*: float32
    time*: float32
    input*: Input

  KeaObj = object
    width: Natural
    height: Natural
    title: string

    frameWidth: Natural
    frameHeight: Natural

    passes: seq[RenderPass]

    pbr*: PBRRenderer

    camera*: Camera

    window: GLFWWindow

    storage: MeshStorage

    ltc: LtcTextures

    input: Input

  Kea* = ref KeaObj

proc `=destroy`(kea: var KeaObj) =
  {.cast(raises: []).}:
    kea.passes.setLen(0) # ensure renderers deallocate before context ends

    kea.pbr = nil

    kea.storage.destroy()

    if kea.window != nil:
      kea.window.destroyWindow()

    glfwTerminate()

proc errorCallback(error: int32, description: cstring) {.cdecl.} =
  echo "GLFW error ", error, ": ", description

proc windowSizeCallback(
    window: GLFWWindow,
    width: int32,
    height: int32,
) {.cdecl.} =
  let kea = cast[Kea](window.getWindowUserPointer())

  kea.width = Natural(width)
  kea.height = Natural(height)

proc framebufferSizeCallback(
    window: GLFWWindow,
    width: int32,
    height: int32,
) {.cdecl.} =
  let kea = cast[Kea](window.getWindowUserPointer())

  kea.frameWidth = Natural(width)
  kea.frameHeight = Natural(height)

  glViewport(0, 0, width, height)

proc initKea*(
    width: Natural,
    height: Natural,
    title: string,
    vertexCapacity: Natural = DEFAULT_VERTEX_CAPACITY,
    indexCapacity: Natural = DEFAULT_INDEX_CAPACITY,
    resizable = false,
): Kea =
  when not defined(release):
    discard glfwSetErrorCallback(errorCallback)

  doAssert glfwInit(), "Failed to initialize GLFW"

  if not resizable:
    glfwWindowHint(GLFWResizable, GLFW_FALSE)

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWSamples, 8)

  let window = glfwCreateWindow(
    int32(width),
    int32(height),
    title,
  )

  doAssert window != nil, "Failed to create GLFW window"

  window.makeContextCurrent()

  doAssert glInit(), "Failed to initialize OpenGL"

  glEnable(GL_DEPTH_TEST)
  glEnable(GL_MULTISAMPLE)

  var frameWidth, frameHeight: int32

  window.getFramebufferSize(
    addr frameWidth,
    addr frameHeight,
  )

  glViewport(0, 0, frameWidth, frameHeight)

  let storage = initMeshStorage(vertexCapacity, indexCapacity)

  let camera = camera.new(Perspective)

  let pbr = pbr.new(storage)

  let pbrPass = RenderPass(
    render: proc(ctx: RenderContext) =
      pbr.render(ctx)
  )

  let ltc = ltc.new()

  result = Kea(
    width: width,
    height: height,
    title: title,
    frameWidth: Natural(frameWidth),
    frameHeight: Natural(frameHeight),
    storage: storage,
    pbr: pbr,
    camera: camera,
    window: window,
    ltc: ltc,
    passes: @[pbrPass]
  )

  window.setWindowUserPointer(cast[pointer](result))

  discard window.setWindowSizeCallback(windowSizeCallback)
  discard window.setFramebufferSizeCallback(framebufferSizeCallback)

proc newMesh*(
    kea: Kea,
    vertices: openArray[Vertex],
    indices: openArray[Index],
): Mesh =
  mesh.new(kea.storage, vertices, indices)

proc newRenderer*[T](
  kea: Kea,
  frag: string,
  vert = DefaultVert,
): Renderer[T] =
  renderer.new(vert = vert, frag = frag, kea.storage)

proc render*(kea: Kea, clear: Color = [0.1, 0.1, 0.1, 1.0]) =
  if kea.frameWidth == 0 or kea.frameHeight == 0:
    return

  glClearColor(clear.r, clear.g, clear.b, clear.a)

  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

  let aspect = kea.frameWidth.float32 / kea.frameHeight.float32

  let ctx = RenderContext(
    view: kea.camera.view,
    proj: kea.camera.proj(aspect),
    eye: kea.camera.positioned
  )

  for pass in kea.passes:
    pass.render(ctx)

  kea.window.swapBuffers()

iterator frames*(kea: Kea): Frame =
  let startTime = glfwGetTime()

  var previousTime = startTime

  while not kea.window.windowShouldClose:
    let currentTime = glfwGetTime()

    let delta = float32(currentTime - previousTime)
    let time = float32(currentTime - startTime)
    let fps = if delta > 0.0: 1.0 / delta else: 0.0

    previousTime = currentTime

    glfwPollEvents()

    kea.input.update(kea.window)

    yield Frame(
      delta: delta,
      fps: fps,
      time: time,
      input: kea.input,
    )
