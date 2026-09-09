import math, mesh, allocator

const SpherePrecision* {.intdefine: "kea.spherePrecision".} = 64

type
  Primitive* = enum
    Triangle
    Quad
    Sphere
    Cube

  Geometry = object
    positions: seq[Vec3]
    normals: seq[Vec3]
    uvs: seq[Vec2]
    indices: seq[uint32]

const TriangleMesh* = Geometry(
  positions: @[
    [ 0.0'f,  1.0, 0.0],
    [-1.0'f, -1.0, 0.0],
    [ 1.0'f, -1.0, 0.0],
  ],
  normals: @[
    [0.0'f, 0.0, 1.0],
    [0.0'f, 0.0, 1.0],
    [0.0'f, 0.0, 1.0],
  ],
  uvs: @[
    [0.5'f, 1.0],
    [0.0'f, 0.0],
    [1.0'f, 0.0],
  ],
  indices: @[0'u32, 1, 2],
)

const QuadMesh* = Geometry(
  positions: @[
    [-1.0'f,  1.0, 0.0],
    [-1.0'f, -1.0, 0.0],
    [ 1.0'f, -1.0, 0.0],
    [ 1.0'f,  1.0, 0.0],
  ],
  normals: @[
    [0.0'f, 0.0, 1.0],
    [0.0'f, 0.0, 1.0],
    [0.0'f, 0.0, 1.0],
    [0.0'f, 0.0, 1.0],
  ],
  uvs: @[
    [0.0'f, 1.0],
    [0.0'f, 0.0],
    [1.0'f, 0.0],
    [1.0'f, 1.0],
  ],
  indices: @[
    0'u32, 1, 2,
    0'u32, 2, 3,
  ],
)

const SphereMesh* = block:
  var geometry: Geometry

  let
    latitudeSegments = SpherePrecision
    longitudeSegments = SpherePrecision * 2

  for latitude in 0 .. latitudeSegments:
    let
      v = latitude.float32 / latitudeSegments.float32
      theta = v * PI.float32
      sinTheta = sin(theta)
      cosTheta = cos(theta)

    for longitude in 0 .. longitudeSegments:
      let
        u = longitude.float32 / longitudeSegments.float32
        phi = u * 2.0'f * PI.float32

        position: Vec3 = [
          sinTheta * cos(phi),
          cosTheta,
          sinTheta * sin(phi),
        ]

      geometry.positions.add position
      geometry.normals.add position
      geometry.uvs.add [u, 1.0'f - v]

  let rowSize = longitudeSegments + 1

  for latitude in 0 ..< latitudeSegments:
    for longitude in 0 ..< longitudeSegments:
      let
        topLeft = latitude * rowSize + longitude
        topRight = topLeft + 1
        bottomLeft = topLeft + rowSize
        bottomRight = bottomLeft + 1

      geometry.indices.add [
        topLeft.uint32,
        topRight.uint32,
        bottomLeft.uint32,

        topRight.uint32,
        bottomRight.uint32,
        bottomLeft.uint32,
      ]

  geometry

const CubeMesh* = Geometry(
  positions: @[
    # Front (+Z)
    [-1.0'f,  1.0,  1.0],
    [-1.0'f, -1.0,  1.0],
    [ 1.0'f, -1.0,  1.0],
    [ 1.0'f,  1.0,  1.0],

    # Back (-Z)
    [ 1.0'f,  1.0, -1.0],
    [ 1.0'f, -1.0, -1.0],
    [-1.0'f, -1.0, -1.0],
    [-1.0'f,  1.0, -1.0],

    # Left (-X)
    [-1.0'f,  1.0, -1.0],
    [-1.0'f, -1.0, -1.0],
    [-1.0'f, -1.0,  1.0],
    [-1.0'f,  1.0,  1.0],

    # Right (+X)
    [1.0'f,  1.0,  1.0],
    [1.0'f, -1.0,  1.0],
    [1.0'f, -1.0, -1.0],
    [1.0'f,  1.0, -1.0],

    # Top (+Y)
    [-1.0'f, 1.0, -1.0],
    [-1.0'f, 1.0,  1.0],
    [ 1.0'f, 1.0,  1.0],
    [ 1.0'f, 1.0, -1.0],

    # Bottom (-Y)
    [-1.0'f, -1.0,  1.0],
    [-1.0'f, -1.0, -1.0],
    [ 1.0'f, -1.0, -1.0],
    [ 1.0'f, -1.0,  1.0],
  ],

  normals: @[
    [0.0'f,  0.0,  1.0],
    [0.0'f,  0.0,  1.0],
    [0.0'f,  0.0,  1.0],
    [0.0'f,  0.0,  1.0],

    [0.0'f,  0.0, -1.0],
    [0.0'f,  0.0, -1.0],
    [0.0'f,  0.0, -1.0],
    [0.0'f,  0.0, -1.0],

    [-1.0'f, 0.0, 0.0],
    [-1.0'f, 0.0, 0.0],
    [-1.0'f, 0.0, 0.0],
    [-1.0'f, 0.0, 0.0],

    [1.0'f, 0.0, 0.0],
    [1.0'f, 0.0, 0.0],
    [1.0'f, 0.0, 0.0],
    [1.0'f, 0.0, 0.0],

    [0.0'f, 1.0, 0.0],
    [0.0'f, 1.0, 0.0],
    [0.0'f, 1.0, 0.0],
    [0.0'f, 1.0, 0.0],

    [0.0'f, -1.0, 0.0],
    [0.0'f, -1.0, 0.0],
    [0.0'f, -1.0, 0.0],
    [0.0'f, -1.0, 0.0],
  ],

  uvs: @[
    [0.0'f, 1.0], [0.0'f, 0.0], [1.0'f, 0.0], [1.0'f, 1.0],
    [0.0'f, 1.0], [0.0'f, 0.0], [1.0'f, 0.0], [1.0'f, 1.0],
    [0.0'f, 1.0], [0.0'f, 0.0], [1.0'f, 0.0], [1.0'f, 1.0],
    [0.0'f, 1.0], [0.0'f, 0.0], [1.0'f, 0.0], [1.0'f, 1.0],
    [0.0'f, 1.0], [0.0'f, 0.0], [1.0'f, 0.0], [1.0'f, 1.0],
    [0.0'f, 1.0], [0.0'f, 0.0], [1.0'f, 0.0], [1.0'f, 1.0],
  ],

  indices: @[
     0'u32,  1,  2,  0'u32,  2,  3,
     4'u32,  5,  6,  4'u32,  6,  7,
     8'u32,  9, 10,  8'u32, 10, 11,
    12'u32, 13, 14, 12'u32, 14, 15,
    16'u32, 17, 18, 16'u32, 18, 19,
    20'u32, 21, 22, 20'u32, 22, 23,
  ],
)

proc mesh(
  allocator: MeshAllocator,
  geometry: Geometry
): Mesh =
  mesh.new(
    allocator,
    positions = geometry.positions,
    normals = geometry.normals,
    uvs = geometry.uvs,
    indices = geometry.indices
  )

proc mesh*(
  allocator: MeshAllocator,
  primitive: Primitive
): Mesh =
  case primitive
  of Triangle: allocator.mesh(TriangleMesh)
  of Quad: allocator.mesh(QuadMesh)
  of Sphere: allocator.mesh(SphereMesh)
  of Cube: allocator.mesh(CubeMesh)
