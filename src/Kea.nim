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
    colors,
    orbit
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
  colors,
  orbit

when isMainModule:
  let kea = initKea(
    width = 800, 
    height = 600, 
    title = "demo"
  )

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
        t = clamp(t, 0.0, 1.0);

        vec3 dark   = vec3(0.045, 0.014, 0.070);
        vec3 purple = vec3(0.250, 0.105, 0.330);
        vec3 blue   = vec3(0.110, 0.360, 0.550);
        vec3 teal   = vec3(0.120, 0.650, 0.610);
        vec3 light  = vec3(0.700, 0.930, 0.820);

        vec3 color = mix(dark, purple, smoothstep(0.0, 0.25, t));
        color = mix(color, blue, smoothstep(0.20, 0.50, t));
        color = mix(color, teal, smoothstep(0.45, 0.75, t));
        return mix(color, light, smoothstep(0.70, 1.0, t));
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

  for frame in kea.frames:
    if frame.keyboard.pressed(Escape):
      break 

    kea.updateOrbitCamera(frame)

    kea.render(clear = White * 0.8)
