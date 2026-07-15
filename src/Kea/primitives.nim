import mesh, transform, material, math, core, drawable

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

proc createMesh*(kea: Kea, primitive: Primitive): Mesh =
  case primitive
  of Triangle: 
    result = createMesh(kea, TriangleMesh.vertices, TriangleMesh.indices)
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
