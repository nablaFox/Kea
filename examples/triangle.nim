# This demosnstrates the creation of a custom renderer for wich we can specify
# custom shaders expecting custom material properties wich can be updated
# dynamically at runtime.

import Kea

let kea = init(
  width = 800, 
  height = 600, 
  title = "triangle"
)

let renderer = kea.newRenderer(
  material = tuple[color: Color],
  globals = (),
  vert = """ 
    void main() {
      gl_Position = vec4(position, 1.0);
    }
  """,
  frag = """
    out vec4 FragColor;

    uniform vec3 color;

    void main() {
      FragColor = vec4(color, 1.0);
    }
  """
)

let triangle = renderer.add(
  Triangle, 
  material = (color: colors.Blue),
  x = 0, 
  y = -1.0, 
  scale = 10, 
  pitch = -PI / 2.0
)

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break 

  triangle.material.color = [frame.time.sin, frame.time.cos, 0.5]

  frame.backbuffer.clear()

  renderer.render(frame.backbuffer)

  frame.present()
