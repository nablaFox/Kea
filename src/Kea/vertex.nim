import math, nimgl/opengl

type
  Vertex* = object
    position*: Vec3
    color*: Vec3
    normal*: Vec3
    uv*: Vec2

  Index* = uint32

  Topology* = enum
    Triangles, Lines, Points,
    LineStrip, LineLoop, TriangleStrip,
    TriangleFan

proc glMode*(topology: Topology): GLenum =
  case topology
  of Triangles: GL_TRIANGLES
  of Lines: GL_LINES
  of Points: GL_POINTS
  of LineStrip: GL_LINE_STRIP
  of LineLoop: GL_LINE_LOOP
  of TriangleStrip: GL_TRIANGLE_STRIP
  of TriangleFan: GL_TRIANGLE_FAN
