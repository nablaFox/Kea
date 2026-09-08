import nimgl/opengl, allocator, math, vertex

export vertex

type
  Mesh* = ref object
    allocator: MeshAllocator

    vertices: seq[Vertex]

    vertexOffset: uint32
    indexOffset: uint32
    indexCount: int

proc uploadVertices(mesh: Mesh) =
  if mesh.vertices.len == 0:
    return

  mesh.allocator.use()

  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(mesh.vertexOffset) * sizeof(Vertex),
    GLsizeiptr(mesh.vertices.len * sizeof(Vertex)),
    addr mesh.vertices[0],
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
    vertexOffset: vertexOffset,
    indexOffset: indexOffset,
    indexCount: indices.len,
  )

  result.uploadVertices()

  if indices.len > 0:
    allocator.use()
    glBufferSubData(
      GL_ELEMENT_ARRAY_BUFFER,
      GLintptr(indexOffset) * sizeof(Index),
      GLsizeiptr(indices.len * sizeof(Index)),
      addr indices[0],
    )

proc update*(mesh: Mesh, positions, normals: openArray[Vec3]) =
  doAssert positions.len == mesh.vertices.len,
    "Position count must match the mesh vertex count"
  doAssert normals.len == mesh.vertices.len,
    "Normal count must match the mesh vertex count"

  for i in 0 ..< positions.len:
    mesh.vertices[i].position = positions[i]
    mesh.vertices[i].normal = normals[i]

  mesh.uploadVertices()

proc draw*(mesh: Mesh, topology: Topology) =
  mesh.allocator.use()

  glDrawElementsBaseVertex(
    topology.glMode,
    GLsizei(mesh.indexCount),
    GL_UNSIGNED_INT,
    cast[pointer](GLintptr(mesh.indexOffset) * sizeof(Index)),
    GLint(mesh.vertexOffset),
  )
