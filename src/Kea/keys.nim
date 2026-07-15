import nimgl/glfw

type
  Key* = enum
    Space
    Escape
    Tab
    Up
    Down
    Left
    Right

proc glfwKey*(key: Key): int32 =
  case key
  of Space: int32(GLFWKey.Space)
  of Escape: int32(GLFWKey.Escape)
  of Tab: int32(GLFWKey.Tab)
  of Up: int32(GLFWKey.Up)
  of Down: int32(GLFWKey.Down)
  of Left: int32(GLFWKey.Left)
  of Right: int32(GLFWKey.Right)
