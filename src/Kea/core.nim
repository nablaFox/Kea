import 
  transform,
  math,
  material,
  camera,
  colors,
  mesh,
  drawable,
  input,
  pbr,
  primitives,
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

    shader: PBRShader

    camera*: Camera

    window: GLFWWindow

    meshStorage: MeshStorage

    drawables: seq[Drawable]

    ltc: LtcTextures

    input: Input

  Kea* = ref KeaObj

proc `=destroy`(kea: KeaObj) =
  {.cast(raises: []).}:
    kea.shader.destroy()

    kea.meshStorage.destroy()

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

  let meshStorage = initMeshStorage(vertexCapacity, indexCapacity)

  let camera = camera.new(Perspective)

  let shader = pbr.new()

  let ltc = ltc.new()

  result = Kea(
    width: width,
    height: height,
    title: title,
    frameWidth: Natural(frameWidth),
    frameHeight: Natural(frameHeight),
    meshStorage: meshStorage,
    shader: shader,
    camera: camera,
    window: window,
    ltc: ltc,
    drawables: @[],
  )

  window.setWindowUserPointer(cast[pointer](result))

  discard window.setWindowSizeCallback(windowSizeCallback)
  discard window.setFramebufferSizeCallback(framebufferSizeCallback)

proc createMesh*(
    kea: Kea,
    vertices: openArray[Vertex],
    indices: openArray[Index],
): Mesh =
  mesh.new(kea.meshStorage, vertices, indices)

proc createMesh*(kea: Kea, primitive: Primitive): Mesh =
  case primitive
  of Triangle: 
    result = createMesh(kea, TriangleMesh.vertices, TriangleMesh.indices)
  of Sphere:
    result = createMesh(kea, SphereMesh.vertices, SphereMesh.indices)
  else:
    discard

proc add*(
    kea: Kea, 
    mesh: Mesh, 
    transform = IdentityTransform, 
    material = Default
): Drawable =
  doAssert mesh != nil, "Cannot add a nil mesh"
  doAssert mesh.storage != nil, "Mesh has no storage"
  doAssert mesh.storage == kea.meshStorage, "Mesh belongs to a different Kea instance"

  result = Drawable(
    transform: transform, 
    material: material, 
    mesh: mesh
  )

  kea.drawables.add(result)

proc add*(
  kea: Kea,
  mesh: Mesh,
  position: Vec3 = vec3(0.0),
  rotation: Vec3 = vec3(0.0),
  scale: Vec3 = vec3(1.0),
  material = Default,
): Drawable =
  kea.add(
    mesh,
    transform.new(position, rotation, scale),
    material
  )

proc add*(
  kea: Kea,
  mesh: Mesh,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  material = Default,
): Drawable =
  kea.add(
    mesh,
    position = [x, y, z],
    rotation = [pitch, yaw, roll],
    scale = [scale, scale, scale],
    material
  )

proc add*(
    kea: Kea,
    primitive: Primitive,
    transform = IdentityTransform,
    material = Default,
): Drawable =
  kea.add(
    kea.createMesh(primitive), 
    transform, 
    material
  )

proc add*(
  kea: Kea,
  primitive: Primitive,
  scale: Vec3 = vec3(1.0),
  rotation: Vec3 = vec3(0.0),
  position: Vec3 = vec3(0.0),
  material = Default,
): Drawable = 
  kea.add(
    kea.createMesh(primitive), 
    transform.new(position, rotation, scale),
    material
  )

proc add*(
  kea: Kea,
  primitive: Primitive,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  material = Default,
): Drawable =
  kea.add(
    kea.createMesh(primitive),
    position = [x, y, z],
    rotation = [pitch, yaw, roll],
    scale = [scale, scale, scale],
    material = material
  )

proc render*(kea: Kea, clear: Color = [0.1, 0.1, 0.1, 1.0]) =
  if kea.frameWidth == 0 or kea.frameHeight == 0:
    return

  glClearColor(clear.r, clear.g, clear.b, clear.a)

  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

  kea.ltc.bindTextures()

  kea.shader.use()

  kea.shader.bindCamera(
    kea.camera, 
    float32(kea.frameWidth) / float32(kea.frameHeight)
  )

  for drawable in kea.drawables:
    kea.shader.bindDrawable(drawable)
    drawable.mesh.draw()

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
