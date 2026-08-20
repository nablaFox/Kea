# This demosnstrates the creation of a custom renderer for wich we can specify
# custom shaders expecting custom material properties wich can be updated
# dynamically at runtime.

import Kea

let kea = init(
  width = 800, 
  height = 600, 
  title = "triangle"
)

let renderer =kea.newRenderer(
  vert = proc(
    vertex: Vertex,
    _: Mat4, _: Mat3,
    material: tuple[color: Color], 
    globals: tuple[],
    position: var Vec4,
    output: var tuple[]
  ) =
    position = vertex.position.hom,

  frag = proc(
    material: tuple[color: Color], 
    globals: tuple[],
    input: tuple[],
    atts: var tuple[color: Vec4]
  ) =
    atts.color = material.color.hom
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
