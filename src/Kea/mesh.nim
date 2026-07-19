import nimgl/opengl, math

type
  Vertex* = object
    position*: Vec3
    normal*: Vec3
    uv*: Vec2

  Index* = uint32

  MeshStorage* = ref object
    vao: GLuint

    vertexBuffer: GLuint
    indexBuffer: GLuint

    nextVertexOffset: uint32
    nextIndexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

  Mesh* = ref object
    storage*: MeshStorage

    vertices: seq[Vertex]
    indices: seq[Index]

    vertexOffset: uint32
    indexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

proc initMeshStorage*(
    vertexCapacity: Natural,
    indexCapacity: Natural,
): MeshStorage =
  var vertexBuffer, indexBuffer: GLuint

  glGenBuffers(1, addr vertexBuffer)
  glGenBuffers(1, addr indexBuffer)

  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBufferData(
    GL_ARRAY_BUFFER,
    vertexCapacity * sizeof(Vertex),
    nil,
    GL_DYNAMIC_DRAW,
  )

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer)
  glBufferData(
    GL_ELEMENT_ARRAY_BUFFER,
    indexCapacity * sizeof(Index),
    nil,
    GL_DYNAMIC_DRAW,
  )

  var vao: GLuint

  glGenVertexArrays(1, addr vao)
  glBindVertexArray(vao)

  glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer)

  glVertexAttribPointer(
    0'u32, 
    3, 
    EGL_FLOAT, 
    false, 
    GLsizei(sizeof(Vertex)), nil
  )
  glEnableVertexAttribArray(0)

  glVertexAttribPointer(
    1'u32, 
    3, 
    EGL_FLOAT, 
    false, 
    GLsizei(sizeof(Vertex)), 
    cast[pointer](offsetof(Vertex, normal))
  )
  glEnableVertexAttribArray(1)

  glVertexAttribPointer(
    2'u32, 
    2, 
    EGL_FLOAT, 
    false, 
    GLsizei(sizeof(Vertex)), 
    cast[pointer](offsetof(Vertex, uv))
  )
  glEnableVertexAttribArray(2)

  result = MeshStorage(
    vao: vao,
    vertexBuffer: vertexBuffer,
    indexBuffer: indexBuffer,
    vertexCapacity: uint32(vertexCapacity),
    indexCapacity: uint32(indexCapacity),
  )

proc upload(mesh: Mesh) = 
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

proc new*(storage: MeshStorage, vertices: openArray[Vertex], indices: openArray[Index]): Mesh =
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

  upload(result)

proc update*(mesh: Mesh, vertices: sink seq[Vertex], indices: sink seq[Index]) =
  doAssert uint32(vertices.len) <= mesh.vertexCapacity
  doAssert uint32(indices.len) <= mesh.indexCapacity

  mesh.vertices = vertices
  mesh.indices = indices

  upload(mesh)

proc destroy*(storage: MeshStorage) =
  glDeleteBuffers(1, addr storage.vertexBuffer)
  glDeleteBuffers(1, addr storage.indexBuffer)
  glDeleteVertexArrays(1, addr storage.vao)

proc indices*(mesh: Mesh): lent seq[Index] =
  mesh.indices

proc vertices*(mesh: Mesh): lent seq[Vertex] =
  mesh.vertices

proc `vertices=`*(mesh: Mesh, vertices: sink seq[Vertex]) =
  doAssert uint32(vertices.len) <= mesh.vertexCapacity
  mesh.vertices = vertices
  upload(mesh)

proc `indices=`*(mesh: Mesh, indices: sink seq[Index]) =
  doAssert uint32(indices.len) <= mesh.indexCapacity
  mesh.indices = indices
  upload(mesh)

proc update*(mesh: Mesh, positions: openArray[Vec3]) =
  # TODO: recalculate new vertices with new normals
  mesh.vertices = @[]

proc draw*(mesh: Mesh) = 
  glDrawElementsBaseVertex(
    GL_TRIANGLES,
    GLsizei(mesh.indices.len),
    GL_UNSIGNED_INT,
    cast[pointer](mesh.indexOffset * uint32(sizeof(Index))),
    GLint(mesh.vertexOffset),
  )
