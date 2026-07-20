import 
  renderer,
  camera,
  colors,
  mesh,
  input,
  primitives,
  transform,
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
    keyboard*: Keyboard
    mouse*: Mouse

  KeaObj = object
    width: Natural
    height: Natural
    title: string

    frameWidth: Natural
    frameHeight: Natural

    window: GLFWWindow

    mouse: Mouse
    keyboard: Keyboard

    passes: seq[RenderPass]

    pbr*: PBRRenderer

    camera*: Camera

    storage: MeshStorage

    ltc: LtcTextures

  Kea* = ref KeaObj

proc `=destroy`(kea: var KeaObj) =
  {.cast(raises: []).}:
    kea.passes = @[]

    kea.pbr = nil

    if kea.storage != nil:
      kea.storage.destroy()
      kea.storage = nil

    kea.ltc.destroy()

    kea.ltc = default(LtcTextures)

    kea.title = ""

    if kea.window != nil:
      kea.window.destroyWindow()
      kea.window = nil

    glfwTerminate()

proc initKea*(
    width: Natural,
    height: Natural,
    title: string,
    vertexCapacity: Natural = DefaultVertexCapacity,
    indexCapacity: Natural = DefaultIndexCapacity,
    resizable = false,
): Kea =
  when not defined(release):
    discard glfwSetErrorCallback(
      proc(error: int32, description: cstring) {.cdecl.} =
        echo "GLFW error ", error, ": ", description
    )

  doAssert glfwInit(), "Failed to initialize GLFW"

  if not resizable:
    glfwWindowHint(GLFWResizable, GLFWFalse)

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglProfile, GLFWOpenglCoreProfile)
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

  var cursorX, cursorY: float64
  window.getCursorPos(addr cursorX, addr cursorY)

  result.mouse.position = [cursorX.float32, cursorY.float32]

  window.setWindowUserPointer(cast[pointer](result))

  discard window.setWindowSizeCallback(
    proc(
      window: GLFWWindow,
      width, height: int32,
    ) {.cdecl.} =
      let kea = cast[Kea](window.getWindowUserPointer())

      kea.width = Natural(width)
      kea.height = Natural(height)
  )

  discard window.setFramebufferSizeCallback(
    proc(
      window: GLFWWindow,
      width, height: int32,
    ) {.cdecl.} =
      let kea = cast[Kea](window.getWindowUserPointer())

      kea.frameWidth = Natural(width)
      kea.frameHeight = Natural(height)

      glViewport(0, 0, width, height)
  )

  discard window.setScrollCallback(
    proc(
      window: GLFWWindow,
      xOffset, yOffset: float64,
    ) {.cdecl.} =
      let kea = cast[Kea](window.getWindowUserPointer())
      kea.mouse.scroll = [xOffset.float32, yOffset.float32]
  )

proc newMesh*(
    kea: Kea,
    vertices: openArray[Vertex],
    indices: openArray[Index],
): Mesh =
  mesh.new(kea.storage, vertices, indices)

proc newRenderer*[T: tuple](
  kea: Kea,
  frag: string,
  vert = DefaultVert,
): Renderer[T] =
  renderer.new(kea.storage, vert = vert, frag = frag)

proc add*[T](
  kea: Kea,
  mesh: Mesh,
  frag: string,
  vert = DefaultVert,
  material: T = (),
  transform = Identity
): Drawable[T] =
  let renderer = renderer.new[T](
    kea.storage,
    frag = frag,
    vert = vert
  )

  kea.passes.add RenderPass(
    render: proc(ctx: RenderContext) =
      renderer.render(ctx)
  )

  renderer.add(mesh, material, transform)

proc add*[T](
  kea: Kea,
  mesh: Mesh,
  frag: string,
  vert = DefaultVert,
  material: T = (),
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0
): Drawable[T] = 
  kea.add(
    mesh = mesh,
    frag = frag,
    vert = vert,
    material = material,
    transform = transform.new(
      x = x,
      y = y,
      z = z,
      pitch = pitch,
      yaw = yaw,
      roll = roll,
      scale = scale
    )
  )

proc add*[T](
  kea: Kea,
  primitive: Primitive,
  frag: string,
  vert = DefaultVert,
  material: T = (),
  transform = Identity
): Drawable[T] =
  kea.add(
    mesh = primitive.mesh(kea.storage), 
    frag = frag, 
    vert = vert, 
    material = material,
    transform = transform
  )

proc add*[T](
  kea: Kea,
  primitive: Primitive,
  frag: string,
  vert = DefaultVert,
  material: T = (),
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0
): Drawable[T] =
  kea.add(
    mesh = primitive.mesh(kea.storage), 
    frag = frag, 
    vert = vert, 
    material = material,
    transform = transform.new(
      x = x,
      y = y,
      z = z,
      pitch = pitch,
      yaw = yaw,
      roll = roll,
      scale = scale
    )
  )

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

    kea.mouse.beginFrame()
    kea.keyboard.beginFrame()

    glfwPollEvents()

    kea.mouse.update(kea.window)
    kea.keyboard.update(kea.window)

    yield Frame(
      delta: delta,
      fps: fps,
      time: time,
      keyboard: kea.keyboard,
      mouse: kea.mouse
    )
