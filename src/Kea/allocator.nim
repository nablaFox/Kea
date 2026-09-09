import core, math

const
  DefaultVertexCapacity {.intdefine: "kea.vertexCapacity".} = 1_000_000
  DefaultIndexCapacity {.intdefine: "kea.indexCapacity".} = 1_000_000

type
  MeshAllocatorObj = object
    kea: Kea

    vao: GLuint

    positionsBuffer: GLuint
    normalsBuffer: GLuint
    colorsBuffer: GLuint
    uvsBuffer: GLuint
    indexBuffer: GLuint

    nextVertexOffset: uint32
    nextIndexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

  MeshAllocator* =
    ref MeshAllocatorObj

proc `=destroy`(allocator: var MeshAllocatorObj) =
  {.cast(raises: []).}:
    if allocator.vao != 0:
      glDeleteVertexArrays(1, addr allocator.vao)
      allocator.vao = 0

    if allocator.positionsBuffer != 0:
      glDeleteBuffers(1, addr allocator.positionsBuffer)
      allocator.positionsBuffer = 0

    if allocator.normalsBuffer != 0:
      glDeleteBuffers(1, addr allocator.normalsBuffer)
      allocator.normalsBuffer = 0

    if allocator.colorsBuffer != 0:
      glDeleteBuffers(1, addr allocator.colorsBuffer)
      allocator.colorsBuffer = 0

    if allocator.uvsBuffer != 0:
      glDeleteBuffers(1, addr allocator.uvsBuffer)
      allocator.uvsBuffer = 0

    if allocator.indexBuffer != 0:
      glDeleteBuffers(1, addr allocator.indexBuffer)
      allocator.indexBuffer = 0

    allocator.kea = nil

proc new*(
  kea: Kea,
  vertexCapacity: Natural = DefaultVertexCapacity,
  indexCapacity: Natural = DefaultIndexCapacity
): MeshAllocator =
  doAssert vertexCapacity.uint64 <= high(uint32).uint64
  doAssert indexCapacity.uint64 <= high(uint32).uint64

  doAssert vertexCapacity <= high(GLsizeiptr) div sizeof(Vec3)
  doAssert vertexCapacity <= high(GLsizeiptr) div sizeof(Vec2)
  doAssert indexCapacity <= high(GLsizeiptr) div sizeof(uint32)

  var allocator = MeshAllocator(
    kea: kea,
    vertexCapacity: vertexCapacity.uint32,
    indexCapacity: indexCapacity.uint32,
  )

  try:
    glGenVertexArrays(1, addr allocator.vao)
    glBindVertexArray(allocator.vao)

    glGenBuffers(1, addr allocator.positionsBuffer)
    glBindBuffer(GL_ARRAY_BUFFER, allocator.positionsBuffer)
    glBufferData(
      GL_ARRAY_BUFFER,
      vertexCapacity * sizeof(Vec3),
      nil,
      GL_DYNAMIC_DRAW
    )
    glVertexAttribPointer(0, 3, EGL_FLOAT, false, 0, nil)
    glEnableVertexAttribArray(0)

    glGenBuffers(1, addr allocator.normalsBuffer)
    glBindBuffer(GL_ARRAY_BUFFER, allocator.normalsBuffer)
    glBufferData(
      GL_ARRAY_BUFFER,
      vertexCapacity * sizeof(Vec3),
      nil,
      GL_DYNAMIC_DRAW
    )
    glVertexAttribPointer(1, 3, EGL_FLOAT, false, 0, nil)
    glEnableVertexAttribArray(1)

    glGenBuffers(1, addr allocator.colorsBuffer)
    glBindBuffer(GL_ARRAY_BUFFER, allocator.colorsBuffer)
    glBufferData(
      GL_ARRAY_BUFFER,
      vertexCapacity * sizeof(Vec3),
      nil,
      GL_DYNAMIC_DRAW
    )
    glVertexAttribPointer(2, 3, EGL_FLOAT, false, 0, nil)
    glEnableVertexAttribArray(2)

    glGenBuffers(1, addr allocator.uvsBuffer)
    glBindBuffer(GL_ARRAY_BUFFER, allocator.uvsBuffer)
    glBufferData(
      GL_ARRAY_BUFFER,
      vertexCapacity * sizeof(Vec2),
      nil,
      GL_DYNAMIC_DRAW
    )
    glVertexAttribPointer(3, 2, EGL_FLOAT, false, 0, nil)
    glEnableVertexAttribArray(3)

    glGenBuffers(1, addr allocator.indexBuffer)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, allocator.indexBuffer)
    glBufferData(
      GL_ELEMENT_ARRAY_BUFFER,
      indexCapacity * sizeof(uint32),
      nil,
      GL_DYNAMIC_DRAW
    )

  except:
    reset allocator
    raise

  allocator

proc allocate*(
  allocator: MeshAllocator,
  vertexCount, indexCount: uint32
): tuple[vertexOffset, indexOffset: uint32] =
  doAssert vertexCount <= allocator.vertexCapacity - allocator.nextVertexOffset
  doAssert indexCount <= allocator.indexCapacity - allocator.nextIndexOffset

  result = (
    allocator.nextVertexOffset,
    allocator.nextIndexOffset
  )

  allocator.nextVertexOffset += vertexCount
  allocator.nextIndexOffset += indexCount

proc use*(allocator: MeshAllocator) =
  glBindVertexArray(allocator.vao)

proc uploadPositions*(
  allocator: MeshAllocator,
  offset: uint32,
  positions: openArray[Vec3]
) =
  if positions.len == 0:
    return

  glBindBuffer(GL_ARRAY_BUFFER, allocator.positionsBuffer)
  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(offset) * sizeof(Vec3),
    GLsizeiptr(positions.len * sizeof(Vec3)),
    unsafeAddr positions[0]
  )

proc uploadNormals*(
  allocator: MeshAllocator,
  offset: uint32,
  normals: openArray[Vec3]
) =
  if normals.len == 0:
    return

  glBindBuffer(GL_ARRAY_BUFFER, allocator.normalsBuffer)
  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(offset) * sizeof(Vec3),
    GLsizeiptr(normals.len * sizeof(Vec3)),
    unsafeAddr normals[0]
  )

proc uploadColors*(
  allocator: MeshAllocator,
  offset: uint32,
  colors: openArray[Vec3]
) =
  if colors.len == 0:
    return

  glBindBuffer(GL_ARRAY_BUFFER, allocator.colorsBuffer)
  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(offset) * sizeof(Vec3),
    GLsizeiptr(colors.len * sizeof(Vec3)),
    unsafeAddr colors[0]
  )

proc uploadUvs*(
  allocator: MeshAllocator,
  offset: uint32,
  uvs: openArray[Vec2]
) =
  if uvs.len == 0:
    return

  glBindBuffer(GL_ARRAY_BUFFER, allocator.uvsBuffer)
  glBufferSubData(
    GL_ARRAY_BUFFER,
    GLintptr(offset) * sizeof(Vec2),
    GLsizeiptr(uvs.len * sizeof(Vec2)),
    unsafeAddr uvs[0]
  )

proc uploadIndices*(
  allocator: MeshAllocator,
  offset: uint32,
  indices: openArray[uint32]
) =
  if indices.len == 0:
    return

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, allocator.indexBuffer)
  glBufferSubData(
    GL_ELEMENT_ARRAY_BUFFER,
    GLintptr(offset) * sizeof(uint32),
    GLsizeiptr(indices.len * sizeof(uint32)),
    unsafeAddr indices[0]
  )
