import transform, math, material, keys, shaders, camera
import nimgl/[glfw, opengl]

type
  Vertex* = object
    position*: Vec3
    normal*: Vec3
    uv*: Vec2

  Index* = uint32

  MeshStorage = ref object
    vertexBuffer: GLuint
    indexBuffer: GLuint

    nextVertexOffset: uint32
    nextIndexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

  Mesh* = ref object
    storage: MeshStorage

    vertices: seq[Vertex]
    indices: seq[Index]

    vertexOffset: uint32
    indexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

  Drawable* = ref object
    mesh: Mesh
    transform: Transform
    material: Material

  Frame* = object
    delta*: float32
    fps*: float32
    time*: float32
    input*: Input

  Input* = object
    kea: Kea

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

    currentKeys: array[Key, bool]
    previousKeys: array[Key, bool]

  Kea* = ref KeaObj

proc `=destroy`(kea: KeaObj) =
  {.cast(raises: []).}:
    glDeleteProgram(kea.shaderProgram)

    glDeleteBuffers(1, unsafeAddr kea.meshStorage.vertexBuffer)
    glDeleteBuffers(1, unsafeAddr kea.meshStorage.indexBuffer)
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
    vertexCapacity: Natural = 10_000,
    indexCapacity: Natural = 30_000,
    resizable = false
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

  let window = glfwCreateWindow(int32(width), int32(height), title)

  doAssert window != nil, "Failed to create GLFW window"

  window.makeContextCurrent()

  doAssert glInit(), "Failed to initialize OpenGL"

  glEnable(GL_DEPTH_TEST)
  glEnable(GL_MULTISAMPLE)

  var frameWidth, frameHeight: int32

  window.getFramebufferSize(
    addr frameWidth,
    addr frameHeight
  )

  glViewport(0, 0, frameWidth, frameHeight)

  var vao, indexBuffer, vertexBuffer: GLuint

  glGenVertexArrays(1, addr vao)
  glGenBuffers(1, addr vertexBuffer)
  glGenBuffers(1, addr indexBuffer)

  glBindVertexArray(vao)

  # Vertex buffer
  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBufferData(GL_ARRAY_BUFFER, vertexCapacity * sizeof(Vertex), nil, GL_DYNAMIC_DRAW)

  # Index buffer
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer)
  glBufferData(
    GL_ELEMENT_ARRAY_BUFFER, indexCapacity * sizeof(Index), nil, GL_DYNAMIC_DRAW
  )

  # Position attribute
  glVertexAttribPointer(0'u32, 3, EGL_FLOAT, false, GLsizei(sizeof(Vertex)), nil)

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

  let shaderProgram = createShaderProgram(defaultVertSource, defaultFragSource)

  let modelLocation = glGetUniformLocation(shaderProgram, "model")

  let viewLocation = glGetUniformLocation(shaderProgram, "view")

  let projLocation = glGetUniformLocation(shaderProgram, "proj")

  let camera = camera(Perspective)

  let storage = MeshStorage(
    vertexBuffer: vertexBuffer,
    indexBuffer: indexBuffer,
    vertexCapacity: uint32(vertexCapacity),
    indexCapacity: uint32(indexCapacity),
    nextVertexOffset: 0,
    nextIndexOffset: 0,
  )

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
    drawables: @[]
  )

  window.setWindowUserPointer(cast[pointer](result))

  discard window.setWindowSizeCallback(windowSizeCallback)
  discard window.setFramebufferSizeCallback(framebufferSizeCallback)

proc uploadMesh(mesh: Mesh) =
  let vertices = mesh.vertices
  let indices = mesh.indices

  let vertexData = if vertices.len > 0: addr mesh.vertices[0] else: nil

  let indexData = if indices.len > 0: addr mesh.indices[0] else: nil

  glBindBuffer(GL_ARRAY_BUFFER, mesh.storage.vertexBuffer)

  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(mesh.vertexOffset * uint32(sizeof(Vertex))),
    GLsizeiptr(vertices.len * sizeof(Vertex)),
    vertexData,
  )

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.storage.indexBuffer)
  glBufferSubData(
    GL_ELEMENT_ARRAY_BUFFER,
    GLintptr(mesh.indexOffset * uint32(sizeof(Index))),
    GLsizeiptr(indices.len * sizeof(Index)),
    indexData,
  )

proc createMesh*(
    kea: Kea, vertices: openArray[Vertex], indices: openArray[Index]
): Mesh =
  let storage = kea.meshStorage

  doAssert storage.nextVertexOffset + uint32(vertices.len) <= storage.vertexCapacity
  doAssert storage.nextIndexOffset + uint32(indices.len) <= storage.indexCapacity

  result = Mesh(
    storage: storage,
    vertices: @vertices,
    indices: @indices,
    vertexOffset: storage.nextVertexOffset,
    indexOffset: storage.nextIndexOffset,
    vertexCapacity: uint32(vertices.len),
    indexCapacity: uint32(indices.len),
  )

  storage.nextVertexOffset += uint32(vertices.len)
  storage.nextIndexOffset += uint32(indices.len)

  uploadMesh(result)

proc update*(mesh: Mesh, vertices: sink seq[Vertex], indices: sink seq[Index]) =
  doAssert uint32(vertices.len) <= mesh.vertexCapacity
  doAssert uint32(indices.len) <= mesh.indexCapacity

  mesh.vertices = vertices
  mesh.indices = indices

  uploadMesh(mesh)

proc indices*(mesh: Mesh): lent seq[Index] =
  mesh.indices

proc vertices*(mesh: Mesh): lent seq[Vertex] =
  mesh.vertices

proc `vertices=`*(mesh: Mesh, vertices: sink seq[Vertex]) =
  doAssert uint32(vertices.len) <= mesh.vertexCapacity
  mesh.vertices = vertices
  uploadMesh(mesh)

proc `indices=`*(mesh: Mesh, indices: sink seq[Index]) =
  doAssert uint32(indices.len) <= mesh.indexCapacity
  mesh.indices = indices
  uploadMesh(mesh)

proc update*(mesh: Mesh, positions: openArray[Vec3]) =
  # TODO: recalculate new vertices with new normals
  mesh.vertices = @[]

proc add*(
    kea: Kea, 
    mesh: Mesh, 
    transform = IdentityTransform, 
    material = DefaultMaterial
): Drawable =
  doAssert mesh.storage == kea.meshStorage,
    "Mesh belongs to a different Kea instance"

  result = Drawable(
    transform: transform, 
    material: material, 
    mesh: mesh
  )

  kea.drawables.add(result)

proc add*(
  kea: Kea,
  mesh: Mesh,
  material = DefaultMaterial,
  position = vec3(0.0),
  rotation = vec3(0.0),
  scale = vec3(1.0),
): Drawable =
  kea.add(
    mesh,
    transform(position, rotation, scale),
    material
  )

proc transform*(drawable: Drawable): var Transform =
  drawable.transform

proc position*(drawable: Drawable): var Vec3 =
  drawable.transform.position

proc positioned*(drawable: Drawable): Vec3 = 
  let transform = drawable.transform
  transform.position

proc scale*(drawable: Drawable): var Vec3 =
  drawable.transform.scale

proc scaled*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.scale  

proc rotation*(drawable: Drawable): var Vec3 =
  drawable.transform.rotation

proc rotated*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.rotation

proc model*(drawable: Drawable): Mat4 =
  drawable.transform.matrix

proc down*(input: Input, key: Key): bool =
  input.kea.currentKeys[key]

proc pressed*(input: Input, key: Key): bool =
  input.kea.currentKeys[key] and not input.kea.previousKeys[key]

proc released*(input: Input, key: Key): bool =
  not input.kea.currentKeys[key] and input.kea.previousKeys[key]

proc render*(kea: Kea) =
  if kea.frameWidth == 0 or kea.frameHeight == 0:
    return

  glClearColor(0.1, 0.1, 0.1, 1.0)
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

  glUseProgram(kea.shaderProgram)
  glBindVertexArray(kea.vao)

  let aspect = float32(kea.frameWidth) / float32(kea.frameHeight)

  let view = kea.camera.view
  let proj = kea.camera.proj(aspect)

  glUniformMatrix4fv(kea.viewLocation, 1, true, addr view[0][0])
  glUniformMatrix4fv(kea.projLocation, 1, true, addr proj[0][0])

  for drawable in kea.drawables:
    let mesh = drawable.mesh
    let model = drawable.transform.matrix

    glUniformMatrix4fv(kea.modelLocation, 1, true, addr model[0][0])

    glDrawElementsBaseVertex(
      GL_TRIANGLES,
      GLsizei(mesh.indices.len),
      GL_UNSIGNED_INT,
      cast[pointer](mesh.indexOffset * uint32(sizeof(Index))),
      GLint(mesh.vertexOffset),
    )

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

    kea.previousKeys = kea.currentKeys

    for key in Key:
      kea.currentKeys[key] = kea.window.getKey(key.glfwKey) == GLFW_PRESS

    yield Frame(
      delta: delta, 
      fps: fps,
      time: time,
      input: Input(kea: kea)
    )
