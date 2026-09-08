import nimgl/opengl, allocator, math, vertex

export vertex

type
  Mesh* = ref object
    allocator: MeshAllocator

    vertices: seq[Vertex]
    indices: seq[Index]

    vertexOffset: uint32
    indexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

proc upload(mesh: Mesh) =
  let
    vertices = mesh.vertices
    indices = mesh.indices

    vertexData = if vertices.len > 0: addr mesh.vertices[0] else: nil

    indexData = if indices.len > 0: addr mesh.indices[0] else: nil

  mesh.allocator.use()

  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(mesh.vertexOffset * sizeof(Vertex).uint32),
    GLsizeiptr(vertices.len * sizeof(Vertex)),
    vertexData,
  )

  glBufferSubData(
    GL_ELEMENT_ARRAY_BUFFER,
    GLintptr(mesh.indexOffset * sizeof(Index).uint32),
    GLsizeiptr(indices.len * sizeof(Index)),
    indexData,
  )

proc new*(
  allocator: MeshAllocator,
  vertices: openArray[Vertex],
  indices: openArray[Index]
): Mesh =
  let (vertexOffset, indexOffset) = allocator.allocate(
    vertices.len.uint32,
    indices.len.uint32
  )

  result = Mesh(
    allocator: allocator,
    vertices: @vertices,
    indices: @indices,
    vertexOffset: vertexOffset,
    indexOffset: indexOffset,
    vertexCapacity: vertices.len.uint32,
    indexCapacity: indices.len.uint32,
  )

  upload(result)

proc update*(
  mesh: Mesh,
  vertices: sink seq[Vertex],
  indices: sink seq[Index]
) =
  doAssert vertices.len.uint32 <= mesh.vertexCapacity
  doAssert indices.len.uint32 <= mesh.indexCapacity

  mesh.vertices = vertices
  mesh.indices = indices

  upload(mesh)

proc indices*(mesh: Mesh): lent seq[Index] =
  mesh.indices

proc vertices*(mesh: Mesh): lent seq[Vertex] =
  mesh.vertices

proc `vertices=`*(mesh: Mesh, vertices: sink seq[Vertex]) =
  doAssert vertices.len.uint32 <= mesh.vertexCapacity
  mesh.vertices = vertices
  upload(mesh)

proc `indices=`*(mesh: Mesh, indices: sink seq[Index]) =
  doAssert indices.len.uint32 <= mesh.indexCapacity
  mesh.indices = indices
  upload(mesh)

proc setVertex*(mesh: Mesh, index: Natural, vertex: Vertex) =
  doAssert index < mesh.vertices.len
  mesh.vertices[index] = vertex
  upload(mesh)

proc update*(
  mesh: Mesh,
  positions: openArray[Vec3]
)
  {.error: "not implemented".} = discard

proc draw*(mesh: Mesh, topology: Topology) =
  mesh.allocator.use()

  glDrawElementsBaseVertex(
    topology.glMode,
    GLsizei(mesh.indices.len),
    GL_UNSIGNED_INT,
    cast[pointer](mesh.indexOffset * sizeof(Index).uint32),
    GLint(mesh.vertexOffset),
  )
