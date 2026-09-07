# This demosnstrates the creation of a custom renderer for wich we can specify
# custom shaders expecting custom material properties wich can be updated
# dynamically at runtime.

import Kea

let
  kea = init(
    title = "triangle",
    width = 800, 
    height = 600, 
  )

  renderer = renderer.new(
    kea,

    vert = proc(vert: Vertex): tuple[pos: Vec4] = 
      result.pos = vert.position.hom,

    frag = proc(color: Color): tuple[pixel: Vec4] =
      result.pixel = color.hom  
  )

  allocator = allocator.new(kea)

  triangle = item.new(
    allocator.mesh(Triangle),
    material = (color: Blue)
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

  renderer.render(frame.backbuffer, triangle)

  frame.present()
