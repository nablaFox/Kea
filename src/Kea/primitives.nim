import std/math, mesh, transform, material, math, core, drawable

const SpherePrecision* {.intdefine: "kea.spherePrecision".} = 64

type
  Primitive* = enum
    Triangle,
    Sphere
    Cube
    Pyramid,

type Geometry = object
  vertices: seq[Vertex]
  indices: seq[Index]

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

proc createMesh*(kea: Kea, primitive: Primitive): Mesh =
  case primitive
  of Triangle: 
    result = createMesh(kea, TriangleMesh.vertices, TriangleMesh.indices)
  of Sphere:
    result = createMesh(kea, SphereMesh.vertices, SphereMesh.indices)
  else:
    discard

proc add*(
    kea: Kea,
    primitive: Primitive,
    transform = IdentityTransform,
    material = DefaultMaterial,
): Drawable =
  kea.add(
    kea.createMesh(primitive), 
    transform, 
    material
  )

proc add*(
  kea: Kea,
  primitive: Primitive,
  scale: Vec3 = vec3(1.0),
  rotation: Vec3 = vec3(0.0),
  position: Vec3 = vec3(0.0),
  material = DefaultMaterial,
): Drawable = 
  kea.add(
    kea.createMesh(primitive), 
    transform(position, rotation, scale),
    material
  )

proc add*(
  kea: Kea,
  primitive: Primitive,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  material = DefaultMaterial,
): Drawable =
  kea.add(
    kea.createMesh(primitive),
    position = [x, y, z],
    rotation = [pitch, yaw, roll],
    scale = [scale, scale, scale],
    material = material
  )
