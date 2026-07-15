import transform, math, material, shaders, camera, colors, mesh, drawable, input
import nimgl/[glfw, opengl]

const
  DefaultVertexCapacity {.intdefine: "kea.vertexCapacity".} = 10_000
  DefaultIndexCapacity {.intdefine: "kea.indexCapacity".} = 30_000

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

    vao: GLuint
    shaderProgram: GLuint
    modelLocation: GLint
    viewLocation: GLint
    projLocation: GLint

    camera*: Camera

    window: GLFWWindow

    meshStorage: MeshStorage

    drawables: seq[Drawable]

    input: Input

  Kea* = ref KeaObj

proc `=destroy`(kea: KeaObj) =
  {.cast(raises: []).}:
    glDeleteProgram(kea.shaderProgram)

    kea.meshStorage.destroy()

    glDeleteVertexArrays(1, unsafeAddr kea.vao)

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

  var vao: GLuint

  glGenVertexArrays(1, addr vao)
  glBindVertexArray(vao)

  let storage = initMeshStorage(vertexCapacity, indexCapacity)

  glBindBuffer(GL_ARRAY_BUFFER, storage.vertexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, storage.indexBuffer)

  # Position attribute
  glVertexAttribPointer(
    0'u32,
    3,
    EGL_FLOAT,
    false,
    GLsizei(sizeof(Vertex)),
    nil,
  )

  glEnableVertexAttribArray(0)

  # Normal attribute
  glVertexAttribPointer(
    1'u32,
    3,
    EGL_FLOAT,
    false,
    GLsizei(sizeof(Vertex)),
    cast[pointer](offsetof(Vertex, normal)),
  )

  glEnableVertexAttribArray(1)

  # UV attribute
  glVertexAttribPointer(
    2'u32,
    2,
    EGL_FLOAT,
    false,
    GLsizei(sizeof(Vertex)),
    cast[pointer](offsetof(Vertex, uv)),
  )

  glEnableVertexAttribArray(2)

  let shaderProgram =
    createShaderProgram(defaultVertSource, defaultFragSource)

  let modelLocation =
    glGetUniformLocation(shaderProgram, "model")

  let viewLocation =
    glGetUniformLocation(shaderProgram, "view")

  let projLocation =
    glGetUniformLocation(shaderProgram, "proj")

  let camera = camera(Perspective)

  result = Kea(
    width: width,
    height: height,

    frameWidth: Natural(frameWidth),
    frameHeight: Natural(frameHeight),

    title: title,

    vao: vao,
    meshStorage: storage,

    shaderProgram: shaderProgram,
    modelLocation: modelLocation,
    viewLocation: viewLocation,
    projLocation: projLocation,

    camera: camera,
    window: window,

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
  mesh.createMesh(kea.meshStorage, vertices, indices)

proc add*(
    kea: Kea, 
    mesh: Mesh, 
    transform = IdentityTransform, 
    material = DefaultMaterial
): Drawable =
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
  material = DefaultMaterial,
): Drawable =
  kea.add(
    mesh,
    transform(position, rotation, scale),
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
  material = DefaultMaterial,
): Drawable =
  kea.add(
    mesh,
    position = [x, y, z],
    rotation = [pitch, yaw, roll],
    scale = [scale, scale, scale],
    material
  )

proc render*(kea: Kea, clearColor: Color = [0.1, 0.1, 0.1, 1.0]) =
  if kea.frameWidth == 0 or kea.frameHeight == 0:
    return

  glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a)
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

  glUseProgram(kea.shaderProgram)
  glBindVertexArray(kea.vao)

  let aspect = float32(kea.frameWidth) / float32(kea.frameHeight)

  let view = kea.camera.view
  let proj = kea.camera.proj(aspect)

  glUniformMatrix4fv(kea.viewLocation, 1, true, addr view[0][0])
  glUniformMatrix4fv(kea.projLocation, 1, true, addr proj[0][0])

  for drawable in kea.drawables:
    let model = drawable.transform.matrix

    glUniformMatrix4fv(kea.modelLocation, 1, true, addr model[0][0])

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
