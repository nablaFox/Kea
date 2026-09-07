import core, vertex

const
  DefaultVertexCapacity {.intdefine: "kea.vertexCapacity".} = 1_000_000
  DefaultIndexCapacity {.intdefine: "kea.indexCapacity".} = 1_000_000

type
  MeshAllocatorObj = object
    kea: Kea

    vao: GLuint

    vertexBuffer: GLuint
    indexBuffer: GLuint

    nextVertexOffset: uint32
    nextIndexOffset: uint32

    vertexCapacity: uint32
    indexCapacity: uint32

  MeshAllocator* = ref MeshAllocatorObj

proc `=destroy`(allocator: var MeshAllocatorObj) =
  {.cast(raises: []).}:
    if allocator.vao != 0:
      glDeleteVertexArrays(1, addr allocator.vao)
      allocator.vao = 0

    if allocator.vertexBuffer != 0:
      glDeleteBuffers(1, addr allocator.vertexBuffer)
      allocator.vertexBuffer = 0

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
  doAssert vertexCapacity <= high(GLsizeiptr) div sizeof(Vertex)
  doAssert indexCapacity <= high(GLsizeiptr) div sizeof(Index)

  var allocator = MeshAllocator(
    kea: kea,
    vertexCapacity: vertexCapacity.uint32,
    indexCapacity: indexCapacity.uint32,
  )

  try:
    glGenVertexArrays(1, addr allocator.vao)
    glBindVertexArray(allocator.vao)

    glGenBuffers(1, addr allocator.vertexBuffer)
    glGenBuffers(1, addr allocator.indexBuffer)

    glBindBuffer(GL_ARRAY_BUFFER, allocator.vertexBuffer)
    glBufferData(
      GL_ARRAY_BUFFER,
      vertexCapacity * sizeof(Vertex),
      nil,
      GL_DYNAMIC_DRAW,
    )

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, allocator.indexBuffer)
    glBufferData(
      GL_ELEMENT_ARRAY_BUFFER,
      indexCapacity * sizeof(Index),
      nil,
      GL_DYNAMIC_DRAW,
    )

    glBindBuffer(GL_ARRAY_BUFFER, allocator.vertexBuffer)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, allocator.indexBuffer)

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
      cast[pointer](offsetOf(Vertex, normal))
    )
    glEnableVertexAttribArray(1)

    glVertexAttribPointer(
      2'u32,
      3,
      EGL_FLOAT,
      false,
      GLsizei(sizeof(Vertex)),
      cast[pointer](offsetOf(Vertex, color))
    )
    glEnableVertexAttribArray(2)

    glVertexAttribPointer(
      3'u32,
      2,
      EGL_FLOAT,
      false,
      GLsizei(sizeof(Vertex)),
      cast[pointer](offsetOf(Vertex, uv))
    )
    glEnableVertexAttribArray(3)

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
  glBindBuffer(GL_ARRAY_BUFFER, allocator.vertexBuffer)
