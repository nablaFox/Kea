import math
import core

type
  Primitive* = enum
    Sphere
    Cube
    Pyramid

  Vertex* = object
    position*: Vec3
    normal*: Vec3
    uv*: Vec2

  Index* = uint32

  Mesh* = object
    state: ref KeaState
    id: HandleId

proc createMesh*(kea: Kea, primitive: Primitive): Mesh =
  discard

proc createMesh*(
  kea: Kea,
  vertices: openArray[Vertex],
  indices: openArray[Index]
): Mesh =
  discard

proc updatePositions*(mesh: Mesh, positions: openArray[Vec3]) =
  discard
