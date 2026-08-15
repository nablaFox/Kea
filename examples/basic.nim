import Kea

let kea = init(
  width = 800, 
  height = 600, 
  title = "basic"
)

let panel = block:
  let renderer = kea.newRenderer(
    material = tuple[radiance: Color],
    globals = (view: Identity4, proj: Identity4),
    vert = """ 
      uniform mat4 view;
      uniform mat4 proj;

      void main() {
        gl_Position = proj * view * model * vec4(position, 1.0);
      }
    """,
    frag = """
      out vec4 FragColor;

      uniform vec3 radiance;

      void main() {
        FragColor = vec4(radiance, 1.0);
      }
    """
  )

  let panel = renderer.add(
    Quad, 
    (radiance: kea.light.radiance),
    transform = transform.new(
      position = kea.light.position
    )
  )

  (
    renderer: renderer,

    render: proc(target: RenderTarget[BackBuffer], camera: Camera) = 
      panel.position = kea.light.position
      panel.rotation = kea.light.rotation
      panel.scale = [kea.light.size.x, kea.light.size.y, 1.0]

      panel.material.radiance = kea.light.radiance

      renderer.view = camera.view
      renderer.proj = camera.proj(target.aspect)

      renderer.render(target)
  )
  
var orbit = orbit.new(
  camera.new(Perspective),
  target = [0.0'f, 1.0, 0.0], 
  distance = 4.0
)

discard kea.add(
  Quad, 
  (
    albedo: [0.32'f, 0.38, 0.43],
    roughness: 0.85'f, 
    metallic: 0.0'f
  ),
  x = 0, 
  y = -1.0, 
  scale = 10, 
  pitch = -PI / 2.0
)

kea.light.position = [0.0'f, 0.0, -5.0]
kea.light.radiance = [10.0'f, 8.0'f, 6.0'f]
kea.light.size.x = 0.5'f

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break 

  frame.backbuffer.clear()

  orbit.update(frame)

  kea.render(frame.backbuffer, orbit.camera)

  panel.render(frame.backbuffer, orbit.camera)

  frame.present()
