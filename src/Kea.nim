import 
  Kea/[
    core, 
    pbr,
    renderer, 
    math, 
    primitives, 
    transform, 
    camera, 
    mesh, 
    input,
    colors
  ], 
  std/math

export 
  core, 
  renderer, 
  math, 
  primitives, 
  transform, 
  camera, 
  pbr,
  mesh, 
  input,
  colors

when isMainModule:
  let kea = initKea(width = 800, height = 600, title = "demo")

  let sphere = kea.add(
    Sphere,
    vert = """
      out vec3 Normal;

      void main() {
        gl_Position = proj * view * model * vec4(position, 1.0);
        Normal = normal;
      }
    """,
    frag = """
      in vec3 Normal;
    
      out vec4 FragColor;

      vec3 palette(float t) {
        vec3 dark = vec3(0.02, 0.04, 0.10);
        vec3 blue = vec3(0.08, 0.42, 0.72);
        vec3 teal = vec3(0.15, 0.78, 0.65);

        vec3 low = mix(dark, blue, smoothstep(0.0, 0.65, t));
        return mix(low, teal, smoothstep(0.55, 1.0, t));
      }

      void main() {
        vec3 direction = normalize(Normal);
        
        float density = max(0, direction.z) / PI;

        float t = pow(clamp(density * PI, 0.0, 1.0), 0.65);

        FragColor = vec4(palette(t), 1.0);
      }
    """,
    z = 0
  )

  discard kea.pbr.add(
    Quad, 
    (
      albedo: [0.32'f32, 0.38, 0.43],
      roughness: 0.85'f32, 
      metallic: 0.0'f32
    ),
    x = 0, 
    y = -1.0, 
    scale = 10, 
    pitch = -PI / 2.0
  )

  var target = [0.0'f32, 0.0, 0.0]
  var distance = 10.0
  var yaw = 0.0'f32
  var pitch = 0.0'f32

  for frame in kea.frames:
    if frame.keyboard.pressed(Escape):
      break 

    if frame.mouse.down(Left):
      yaw -= frame.mouse.delta.x * frame.delta * 0.5
      pitch -= frame.mouse.delta.y * frame.delta * 0.5

    if frame.mouse.down(Middle):
      let right = kea.camera.right
      let up = kea.camera.up

      target -= right * frame.mouse.delta.x * 0.005
      target += up * frame.mouse.delta.y * 0.005

    yaw = clamp(yaw, -PI, PI)
    pitch = clamp(pitch, -PI / 2, 0.0)
    distance *= 0.85 ^ frame.mouse.scroll.y

    let orbit = transform.new(yaw = yaw, pitch = pitch)

    let offset = orbit.rotMatrix3 * [0.0'f32, 0.0, 1.0]

    kea.camera.position = target + offset * distance
    kea.camera.rotation = [pitch, yaw, 0.0]

    kea.render(clear = White * 0.8)
