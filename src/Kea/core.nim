import transform, math, material, keys, shaders
import nimgl/[glfw, opengl]

type
  Vertex* = object
    position*: Vec3
    normal*: Vec3
    uv*: Vec2

  Index* = uint32

  HandleId = Natural

  DrawableData = object
    transform: Transform
    material: Material
    mesh: HandleId

  MeshData = object
    vertices: seq[Vertex]
    indices: seq[Index]

    vertexOffset: uint32
    indexOffset: uint32

  KeaState = object
    width: Natural
    height: Natural
    title: string

    vao: GLuint
    vertexBuffer: GLuint
    indexBuffer: GLuint

    shaderProgram: GLuint

    window: GLFWWindow

    meshes: seq[MeshData]
    drawables: seq[DrawableData]

    currentKeys: array[Key, bool]
    previousKeys: array[Key, bool]

  Drawable* = object
    state: ref KeaState
    handle: HandleId

  Mesh* = object
    state: ref KeaState
    handle: HandleId

  Frame* = object
    delta*: float32
    input*: Input

  Input* = object
    state: ref KeaState

  Kea* = object
    state: ref KeaState

proc errorCallback(error: int32, description: cstring) {.cdecl.} =
  echo "GLFW error ", error, ": ", description

proc initKea*(
  width: Natural, 
  height: Natural, 
  title: string,
  vertexCapacity: Natural = 10_000,
  indexCapacity: Natural = 30_000
): Kea = 
  when not defined(release):
    discard glfwSetErrorCallback(errorCallback)

  doAssert glfwInit(), "Failed to initialize GLFW"

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

  var vao, indexBuffer, vertexBuffer: GLuint

  glGenVertexArrays(1, addr vao)
  glGenBuffers(1, addr vertexBuffer)
  glGenBuffers(1, addr indexBuffer)

  glBindVertexArray(vao)

  # Vertex buffer
  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBufferData(
    GL_ARRAY_BUFFER,
    vertexCapacity * sizeof(Vertex),
    nil,
    GL_DYNAMIC_DRAW
  )

  # Index buffer
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer)
  glBufferData(
    GL_ELEMENT_ARRAY_BUFFER,
    indexCapacity * sizeof(Index),
    nil,
    GL_DYNAMIC_DRAW
  )

  # Position attribute
  glVertexAttribPointer(
    0'u32,
    3,
    EGL_FLOAT,
    false,
    GLsizei(sizeof(Vertex)),
    nil
  )

  glEnableVertexAttribArray(0)

  # Normal attribute
  glVertexAttribPointer(
    1'u32,
    3,
    EGL_FLOAT,
    false,
    GLsizei(sizeof(Vertex)),
    cast[pointer](offsetof(Vertex, normal))
  )

  glEnableVertexAttribArray(1)

  # UV attribute
  glVertexAttribPointer(
    2'u32,
    2,
    EGL_FLOAT,
    false,
    GLsizei(sizeof(Vertex)),
    cast[pointer](offsetof(Vertex, uv))
  )

  glEnableVertexAttribArray(2)

  let shaderProgram = createShaderProgram(defaultVertSource, defaultFragSource)

  result.state = (ref KeaState)(
    width: width,
    height: height,
    title: title,

    vao: vao,
    vertexBuffer: vertexBuffer,
    indexBuffer: indexBuffer,

    shaderProgram: shaderProgram,

    window: window,

    meshes: @[],
    drawables: @[],
  )

proc `=destroy`*(kea: Kea) = 
  glDeleteProgram(kea.state.shaderProgram)

  glDeleteBuffers(1, addr kea.state.vertexBuffer)
  glDeleteBuffers(1, addr kea.state.indexBuffer)
  glDeleteVertexArrays(1, addr kea.state.vao)

  kea.state.window.destroyWindow()

  glfwTerminate()

proc allocateMeshData(
    state: ref KeaState,
    vertices: openArray[Vertex],
    indices: openArray[Index],
    indexOffset: uint32,
    vertexOffset: uint32,
): MeshData =
  let vertexData =
    if vertices.len > 0: addr vertices[0]
    else: nil

  let indexData =
    if indices.len > 0: addr indices[0]
    else: nil
  
  glBindBuffer(GL_ARRAY_BUFFER, state.vertexBuffer)

  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(vertexOffset * uint32(sizeof(Vertex))),
    GLsizeiptr(vertices.len * sizeof(Vertex)),
    vertexData
  )

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, state.indexBuffer)
  glBufferSubData(
    GL_ELEMENT_ARRAY_BUFFER,
    GLintptr(indexOffset * uint32(sizeof(Index))),
    GLsizeiptr(indices.len * sizeof(Index)),
    indexData
  )

  MeshData(
    vertices: @vertices,
    indices: @indices,
    indexOffset: indexOffset,
    vertexOffset: vertexOffset,
  )

proc createMesh*(
    kea: Kea, 
    vertices: openArray[Vertex], 
    indices: openArray[Index]
): Mesh =
  let last = if kea.state.meshes.len > 0: kea.state.meshes[^1] else: default(MeshData)

  let vertexOffset = last.vertexOffset + uint32(last.vertices.len)
  let indexOffset  = last.indexOffset  + uint32(last.indices.len)

  let meshData = allocateMeshData(
    kea.state, 
    vertices, 
    indices, 
    vertexOffset=vertexOffset, 
    indexOffset=indexOffset
  )

  let handle = kea.state.meshes.len

  kea.state.meshes.add(meshData)

  Mesh(state: kea.state, handle: handle)

proc update*(
  mesh: Mesh, 
  vertices: openArray[Vertex], 
  indices: openArray[Index]
) =
  let index = mesh.handle
  let old = mesh.state.meshes[index]

  doAssert vertices.len <= old.vertices.len
  doAssert indices.len <= old.indices.len

  mesh.state.meshes[index] = allocateMeshData(
    mesh.state,
    vertices,
    indices,
    indexOffset = old.indexOffset,
    vertexOffset = old.vertexOffset,
  )

proc indices*(mesh: Mesh): seq[Index] =
  mesh.state.meshes[mesh.handle].indices

proc vertices*(mesh: Mesh): seq[Vertex] =
  mesh.state.meshes[mesh.handle].vertices

proc `vertices=`*(mesh: Mesh, vertices: seq[Vertex]) =
  mesh.update(vertices, mesh.indices)

proc update*(mesh: Mesh, positions: openArray[Vec3]) =
  # TODO: recalculate new vertices with new normals
  mesh.vertices = @[]

proc add*(
    kea: Kea, 
    mesh: Mesh, 
    transform = IdentityTransform, 
    material = DefaultMaterial
): Drawable =
  let handle = kea.state.drawables.len

  let drawableData = DrawableData(
    transform: transform,
    material: material,
    mesh: mesh.handle
  )

  kea.state.drawables.add(drawableData)

  Drawable(state: kea.state, handle: handle)

proc down*(input: Input, key: Key): bool = discard
  input.state.currentKeys[key]

proc pressed*(input: Input, key: Key): bool =
  input.state.currentKeys[key] and
    not input.state.previousKeys[key]

proc released*(input: Input, key: Key): bool =
  not input.state.currentKeys[key] and
    input.state.previousKeys[key]

proc render*(kea: Kea) = 
  glClearColor(0.1, 0.1, 0.1, 1.0)
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
     
  glUseProgram(kea.state.shaderProgram)
  glBindVertexArray(kea.state.vao)

  for drawable in kea.state.drawables:
    let mesh = kea.state.meshes[drawable.mesh]

    glDrawElementsBaseVertex(
      GL_TRIANGLES,
      GLsizei(mesh.indices.len),
      GL_UNSIGNED_INT,
      cast[pointer](mesh.indexOffset * uint32(sizeof(Index))),
      GLint(mesh.vertexOffset)
    )

    kea.state.window.swapBuffers() 

iterator frames*(kea: Kea): Frame =
  var previousTime = glfwGetTime()

  while not kea.state.window.windowShouldClose:
    let currentTime = glfwGetTime()

    let delta = float32(currentTime - previousTime)

    previousTime = currentTime

    glfwPollEvents()

    kea.state.previousKeys = kea.state.currentKeys

    for key in Key:
      kea.state.currentKeys[key] = kea.state.window.getKey(int32(key)) == GLFW_PRESS

    yield Frame(delta: delta, input: Input(state: kea.state))
