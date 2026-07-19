import std/math, mesh

const SpherePrecision* {.intdefine: "kea.spherePrecision".} = 64

type
  Primitive* = enum
    Triangle,
    Sphere
    Cube
    Pyramid,

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
        phi = u * 2.0'f32 * PI.float32

        x = sinTheta * cos(phi)
        y = cosTheta
        z = sinTheta * sin(phi)

      geometry.vertices.add Vertex(
        position: [x, y, z],
        normal: [x, y, z],
        uv: [u, 1.0'f32 - v],
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

proc mesh*(primitive: Primitive, storage: MeshStorage): Mesh =
  case primitive
  of Triangle: 
    result = mesh.new(storage, TriangleMesh.vertices, TriangleMesh.indices)
  of Sphere:
    result = mesh.new(storage, SphereMesh.vertices, SphereMesh.indices)
  else:
    discard
