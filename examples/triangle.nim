# This demosnstrates the creation of a custom renderer for wich we can specify
# custom shaders expecting custom material properties wich can be updated
# dynamically at runtime.

import Kea

let kea = init(
  width = 800, 
  height = 600, 
  title = "triangle"
)

let renderer = kea.renderer(
  vert = proc(vert: Vertex): tuple[pos: Vec4] = 
    result.pos = vert.position.hom,

  frag = proc(color: Color): tuple[pixel: Vec4] =
    result.pixel = color.hom  
)

let triangle = renderer.add(
  Triangle, 
  material = (color: colors.Blue)
)

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break

  triangle.material.color = [
    frame.time.sin, 
    frame.time.cos, 
    0.5
  ]

  frame.backbuffer.clear()

  renderer.render(frame.backbuffer)

  frame.present()
