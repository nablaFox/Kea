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
    title = "demo",
    orbit = orbit.new(target = [0.0'f32, 1.0, 0.0], distance = 4.0)
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

      uniform vec4 M;

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

      float D0(vec3 wo) {
        return max(0.0, wo.z) / PI;
      }

      void main() {
        mat3 inv = inverse(mat3(
          vec3(M.x, 0.0, M.w),
          vec3(0.0, M.z, 0.0),
          vec3(M.y, 0.0, 1.0)
        ));

        vec3 wi = normalize(Normal);

        vec3 wo = inv * wi;

        float jacobian = determinant(inv) / pow(length(wo), 3);
        
        float density = D0(normalize(wo)) * jacobian;

        float t = pow(clamp(density * PI, 0.0, 1.0), 0.65);

        FragColor = vec4(palette(t), 1.0);
      }
    """,
    transform = transform.new(position = kea.orbit.target),
    material = (M: [1.0'f32, 0.0, 1.0, 0.0])
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

  var component = 0

  for frame in kea.frames:
    if frame.keyboard.pressed(Escape):
      break 

    if frame.keyboard.down(One): 
      component = 0

    if frame.keyboard.down(Two): 
      component = 1
    
    if frame.keyboard.down(Three): 
      component = 2

    if frame.keyboard.down(Four): 
      component = 3

    if frame.keyboard.down(Space):
      sphere.material.M[component] += 0.01

    if frame.keyboard.down(LeftShift):
      sphere.material.M[component] -= 0.01

    if frame.keyboard.pressed(Tab):
      sphere.material.M = [1.0'f32, 0.0, 1.0, 0.0]

    kea.updateOrbitCamera(frame)

    kea.render(clear = White * 0.8)
