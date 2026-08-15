import std/math, mesh

const SpherePrecision* {.intdefine: "kea.spherePrecision".} = 64

type
  Primitive* = enum
    Triangle
    Quad
    Sphere
    Cube

type Geometry = object
  vertices*: seq[Vertex]
  indices*: seq[Index]

const TriangleMesh* = Geometry(
  vertices: @[
    Vertex(position: [0.0, 1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [0.5, 1.0]),
    Vertex(position: [-1.0, -1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [0.0, 0.0]),
    Vertex(position: [1.0, -1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [1.0, 0.0])
  ],
  indices: @[0'u32, 1'u32, 2'u32],
)

const QuadMesh* = Geometry(
  vertices: @[
    Vertex(position: [-1.0,  1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [0.0, 1.0]),
    Vertex(position: [-1.0, -1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [0.0, 0.0]),
    Vertex(position: [ 1.0, -1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [1.0, 0.0]),
    Vertex(position: [ 1.0,  1.0, 0.0], normal: [0.0, 0.0, 1.0], uv: [1.0, 1.0])
  ],
  indices: @[
    0'u32, 1'u32, 2'u32,
    0'u32, 2'u32, 3'u32
  ],
)

const SphereMesh* = block:
  var geometry: Geometry

  let
    latitudeSegments = SpherePrecision
    longitudeSegments = SpherePrecision * 2

  for latitude in 0..latitudeSegments:
    let
      v = float32(latitude) / float32(latitudeSegments)
      theta = v * PI.float32

      sinTheta = sin(theta)
      cosTheta = cos(theta)

    for longitude in 0..longitudeSegments:
      let
        u = float32(longitude) / float32(longitudeSegments)
        phi = u * 2.0'f * PI.float32

        x = sinTheta * cos(phi)
        y = cosTheta
        z = sinTheta * sin(phi)

      geometry.vertices.add Vertex(
        position: [x, y, z],
        normal: [x, y, z],
        uv: [u, 1.0'f - v],
      )

  let rowSize = longitudeSegments + 1

  for latitude in 0..<latitudeSegments:
    for longitude in 0..<longitudeSegments:
      let
        topLeft = latitude * rowSize + longitude
        topRight = topLeft + 1
        bottomLeft = topLeft + rowSize
        bottomRight = bottomLeft + 1

      geometry.indices.add [
        Index(topLeft),
        Index(bottomLeft),
        Index(topRight),

        Index(topRight),
        Index(bottomLeft),
        Index(bottomRight),
      ]

  geometry

const CubeMesh* = Geometry(
  vertices: @[
    # Front (+Z)
    Vertex(position: [-1.0,  1.0,  1.0], normal: [0.0, 0.0, 1.0], uv: [0.0, 1.0]),
    Vertex(position: [-1.0, -1.0,  1.0], normal: [0.0, 0.0, 1.0], uv: [0.0, 0.0]),
    Vertex(position: [ 1.0, -1.0,  1.0], normal: [0.0, 0.0, 1.0], uv: [1.0, 0.0]),
    Vertex(position: [ 1.0,  1.0,  1.0], normal: [0.0, 0.0, 1.0], uv: [1.0, 1.0]),

    # Back (-Z)
    Vertex(position: [ 1.0,  1.0, -1.0], normal: [0.0, 0.0, -1.0], uv: [0.0, 1.0]),
    Vertex(position: [ 1.0, -1.0, -1.0], normal: [0.0, 0.0, -1.0], uv: [0.0, 0.0]),
    Vertex(position: [-1.0, -1.0, -1.0], normal: [0.0, 0.0, -1.0], uv: [1.0, 0.0]),
    Vertex(position: [-1.0,  1.0, -1.0], normal: [0.0, 0.0, -1.0], uv: [1.0, 1.0]),

    # Left (-X)
    Vertex(position: [-1.0,  1.0, -1.0], normal: [-1.0, 0.0, 0.0], uv: [0.0, 1.0]),
    Vertex(position: [-1.0, -1.0, -1.0], normal: [-1.0, 0.0, 0.0], uv: [0.0, 0.0]),
    Vertex(position: [-1.0, -1.0,  1.0], normal: [-1.0, 0.0, 0.0], uv: [1.0, 0.0]),
    Vertex(position: [-1.0,  1.0,  1.0], normal: [-1.0, 0.0, 0.0], uv: [1.0, 1.0]),

    # Right (+X)
    Vertex(position: [1.0,  1.0,  1.0], normal: [1.0, 0.0, 0.0], uv: [0.0, 1.0]),
    Vertex(position: [1.0, -1.0,  1.0], normal: [1.0, 0.0, 0.0], uv: [0.0, 0.0]),
    Vertex(position: [1.0, -1.0, -1.0], normal: [1.0, 0.0, 0.0], uv: [1.0, 0.0]),
    Vertex(position: [1.0,  1.0, -1.0], normal: [1.0, 0.0, 0.0], uv: [1.0, 1.0]),

    # Top (+Y)
    Vertex(position: [-1.0, 1.0, -1.0], normal: [0.0, 1.0, 0.0], uv: [0.0, 1.0]),
    Vertex(position: [-1.0, 1.0,  1.0], normal: [0.0, 1.0, 0.0], uv: [0.0, 0.0]),
    Vertex(position: [ 1.0, 1.0,  1.0], normal: [0.0, 1.0, 0.0], uv: [1.0, 0.0]),
    Vertex(position: [ 1.0, 1.0, -1.0], normal: [0.0, 1.0, 0.0], uv: [1.0, 1.0]),

    # Bottom (-Y)
    Vertex(position: [-1.0, -1.0,  1.0], normal: [0.0, -1.0, 0.0], uv: [0.0, 1.0]),
    Vertex(position: [-1.0, -1.0, -1.0], normal: [0.0, -1.0, 0.0], uv: [0.0, 0.0]),
    Vertex(position: [ 1.0, -1.0, -1.0], normal: [0.0, -1.0, 0.0], uv: [1.0, 0.0]),
    Vertex(position: [ 1.0, -1.0,  1.0], normal: [0.0, -1.0, 0.0], uv: [1.0, 1.0]),
  ],

  indices: @[
    0'u32,  1'u32,  2'u32,
    0'u32,  2'u32,  3'u32,

    4'u32,  5'u32,  6'u32,
    4'u32,  6'u32,  7'u32,

    8'u32,  9'u32, 10'u32,
    8'u32, 10'u32, 11'u32,

    12'u32, 13'u32, 14'u32,
    12'u32, 14'u32, 15'u32,

    16'u32, 17'u32, 18'u32,
    16'u32, 18'u32, 19'u32,

    20'u32, 21'u32, 22'u32,
    20'u32, 22'u32, 23'u32,
  ],
)

proc mesh*(primitive: Primitive, storage: MeshStorage): Mesh =
  case primitive
  of Triangle:
    result = mesh.new(storage, TriangleMesh.vertices, TriangleMesh.indices)

  of Quad:
    result = mesh.new(storage, QuadMesh.vertices, QuadMesh.indices)

  of Sphere:
    result = mesh.new(storage, SphereMesh.vertices, SphereMesh.indices)

  of Cube:
    result = mesh.new(storage, CubeMesh.vertices, CubeMesh.indices)
