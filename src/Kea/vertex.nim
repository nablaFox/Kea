import math

type
  Vertex* = object
    position*: Vec3
    color*: Vec3
    normal*: Vec3
    uv*: Vec2

  Index* = uint32

  Topology* = enum
    Triangles, Lines, Points
