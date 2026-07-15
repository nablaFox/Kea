import nimgl/glfw

type
  Key* = enum
    Space
    Escape

proc glfwKey*(key: Key): int32 =
  case key
  of Space: int32(GLFWKey.Space)
  of Escape: int32(GLFWKey.Escape)
