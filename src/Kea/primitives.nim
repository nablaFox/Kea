import core, transform, material, math
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
  material = DefaultMaterial,
  scale = vec3(1.0),
  rotation = vec3(0.0),
  position = vec3(0.0),
): Drawable = 
  kea.add(
    kea.createMesh(primitive), 
    material,
    position,
    rotation,
    scale
  )
