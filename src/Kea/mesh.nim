import nimgl/opengl, allocator, math

type
  Topology* = enum
    Triangles, Lines, Points,
    LineStrip, LineLoop, TriangleStrip,
    TriangleFan

  Mesh* = ref object
    allocator: MeshAllocator

    vertexOffset: uint32
    indexOffset: uint32

    vertexCount: int
    indexCount: int

proc new*(
  allocator: MeshAllocator,
  vertexCount: Natural,
  indexCount: Natural
): Mesh =
  let (vertexOffset, indexOffset) = allocator
    .allocate(
      vertexCount.uint32,
      indexCount.uint32
    )

  Mesh(
    allocator: allocator,
    vertexOffset: vertexOffset,
    indexOffset: indexOffset,
    vertexCount: vertexCount,
    indexCount: indexCount
  )

proc update*(
  mesh: Mesh,
  positions: openArray[Vec3],
  normals: openArray[Vec3],
  colors: openArray[Vec3] = [],
  uvs: openArray[Vec2] = [],
  indices: openArray[uint32] = []
) =
  doAssert positions.len == mesh.vertexCount,
    "Position count must match the mesh vertex count"

  doAssert normals.len == mesh.vertexCount,
    "Normal count must match the mesh vertex count"

  doAssert colors.len == 0 or colors.len == mesh.vertexCount,
    "Color count must match the mesh vertex count"

  doAssert uvs.len == 0 or uvs.len == mesh.vertexCount,
    "UV count must match the mesh vertex count"

  mesh.allocator.uploadPositions(mesh.vertexOffset, positions)
  mesh.allocator.uploadNormals(mesh.vertexOffset, normals)
  mesh.allocator.uploadColors(mesh.vertexOffset, colors)
  mesh.allocator.uploadUvs(mesh.vertexOffset, uvs)
  mesh.allocator.uploadIndices(mesh.indexOffset, indices)

proc new*(
  allocator: MeshAllocator,
  positions: openArray[Vec3],
  normals: openArray[Vec3],
  indices: openArray[uint32],
  uvs: openArray[Vec2] = [],
  colors: openArray[Vec3] = []
): Mesh =
  let
    vertexCount = positions.len.Natural
    indexCount = indices.len.Natural

  result = new(
    allocator,
    vertexCount,
    indexCount
  )

  result.update(
    positions,
    normals,
    colors,
    uvs,
    indices
  )

proc glMode*(topology: Topology): GLenum =
  case topology
  of Triangles: GL_TRIANGLES
  of Lines: GL_LINES
  of Points: GL_POINTS
  of LineStrip: GL_LINE_STRIP
  of LineLoop: GL_LINE_LOOP
  of TriangleStrip: GL_TRIANGLE_STRIP
  of TriangleFan: GL_TRIANGLE_FAN

proc draw*(mesh: Mesh, topology: Topology) =
  mesh.allocator.use()

  glDrawElementsBaseVertex(
    topology.glMode,
    GLsizei(mesh.indexCount),
    GL_UNSIGNED_INT,
    cast[pointer](GLintptr(mesh.indexOffset) * sizeof(uint32)),
    GLint(mesh.vertexOffset),
  )

proc vertexCount*(mesh: Mesh): int =
  mesh.vertexCount

proc indexCount*(mesh: Mesh): int =
  mesh.indexCount
