import Kea, std/[random, sequtils]

type McmlMaterial = tuple[
  transmittance: ColorTexture,
  diffuse: ColorTexture,
  photons: uint32,
  size: float32
]

type Mcml = object
  absorption: float32
  scattering: float32
  anisotropy: float32
  depth: float32
  resolution: Natural

  transmittance: seq[float32]
  diffuse: seq[float32]

  renderer: Renderer[
    tuple[view: Mat4, proj: Mat4], 
    McmlMaterial
  ]

  slab: RenderItem[McmlMaterial]

proc add(
  kea: Kea,
  resolution: Natural,
  transform: Transform,
  depth: float32,
  size: float32,
  absorption: float32,
  scattering: float32,
  anisotropy: float32
): Mcml =
  let renderer = kea.newRenderer(
    material = McmlMaterial,
    globals = (
      view: Identity4,
      proj: Identity4
    ),
    vert = """
      uniform mat4 view;
      uniform mat4 proj;

      out vec3 ObjectNormal;
      out vec3 WorldNormal;
      out vec2 UV;

      void main() {
        gl_Position =
          proj * view * model * vec4(position, 1.0);

        ObjectNormal = normal;
        WorldNormal = normalize(nmat * normal);
        UV = uv;
      }
    """,
    frag = """
      in vec3 ObjectNormal;
      in vec3 WorldNormal;
      in vec2 UV;

      out vec4 FragColor;

      layout(bindless_sampler)
      uniform sampler2D transmittance;

      layout(bindless_sampler)
      uniform sampler2D diffuse;

      uniform uint photons;
      uniform float size;

      float tonemap(float x) {
        const float exposure = 1.0;
        return 1.0 - exp(-x * exposure);
      }

      float powerDensity(sampler2D tex, vec2 uv) {
        ivec2 res = textureSize(tex, 0);

        float texelArea = 
          (size / float(res.x)) *
          (size / float(res.y));

        return texture(tex, uv).r / (float(photons) * texelArea);
      }

      void main() {
        vec3 color;

        if (ObjectNormal.x > 0.99) {
          float T = powerDensity(transmittance, UV);

          vec3 transmissionColor = vec3(0.20, 0.65, 0.95);

          color = transmissionColor * tonemap(T);
        } else if (ObjectNormal.x < -0.99) {
          float D = powerDensity(diffuse, UV);

          vec3 diffuseColor = vec3(0.35, 0.55, 1.0);

          color = diffuseColor * tonemap(D);
        } else {
          vec3 N = normalize(WorldNormal);
          vec3 L = normalize(vec3(0.4, 0.8, 0.6));

          float ndotl = max(dot(N, L), 0.0);

          float lighting = 0.35 + 0.65 * ndotl;

          vec3 slabColor = vec3(0.28, 0.42, 0.48);

          color = slabColor * lighting;
        }

        FragColor = vec4(
          pow(max(color, vec3(0.0)), vec3(1.0 / 2.2)),
          1.0
        );
      }
    """
  )

  let slab = renderer.add(
    Cube,
    (
      transmittance: texture.new(
        width = resolution, 
        height = resolution, 
        format = R32Float,
        DataTextureOptions
      ),
      diffuse: texture.new(
        width = resolution, 
        height = resolution, 
        format = R32Float,
        DataTextureOptions
      ),
      photons: 0'u32,
      size: size
    ),
    transform
  )

  Mcml(
    absorption: absorption,
    scattering: scattering,
    anisotropy: anisotropy,
    depth: depth,
    resolution: resolution,

    transmittance: newSeq[float32](resolution * resolution),
    diffuse: newSeq[float32](resolution * resolution),

    renderer: renderer,
    slab: slab
  )

proc render(mcml: Mcml, backbuffer: RenderTarget, camera: Camera) = 
  mcml.renderer.view = camera.view
  mcml.renderer.proj = camera.proj(backbuffer.aspect)

  mcml.slab.scale = block:
    let s = mcml.slab.material.size
    [mcml.depth, s, s]

  mcml.renderer.render(backbuffer)

proc update(mcml: var Mcml, photons: Natural) = 
  let 
    N = mcml.resolution
    depth = mcml.depth
    absorption = mcml.absorption
    scattering = mcml.scattering
    anisotropy = mcml.anisotropy
    size = mcml.slab.material.size

  proc photonRandomWalk(): tuple[
    weight: float32, 
    pos: Vec3,
    dir: Vec3
  ] =
    var weight = 1.0'f
    var pos = [0.0'f, 0.0, 0.0]
    var dir = [0.0'f, 0.0, 1.0]

    let q = absorption / (absorption + scattering)

    while true:
      let boundary = 
        if dir.z > 0: (depth - pos.z) / dir.z
        elif dir.z < 0: - pos.z / dir.z
        else: Inf.float32

      # sampled from Exp(scattering) (Beer-Lambert law)
      let dist = - ln(rand(1.0)) / (absorption + scattering)

      if dist >= boundary:
        pos += dir * boundary
        break

      pos += dir * dist

      weight *= (1 - q)

      # sampled from Henyey-Greenstein
      let cosTheta = 
        if anisotropy == 0: 2 * rand(1.0) - 1
        else:
          let g = anisotropy
          let r = rand(1.0)

          (1 + g^2 - ((1 - g^2) / (1 - g + 2*g*r))^2) / (2*g)

      let phi = 2 * PI * rand(1.0)

      let theta = arccos cosTheta.clamp(-1.0'f, 1.0'f)

      dir = dir.rotate(theta, phi).normalize

    (weight: weight, pos: pos, dir: dir)
    
  for i in 0..<photons:
    let (weight, pos, dir) = photonRandomWalk()

    # mappping [-size/2, size/2] x [-size/2, size/2] -> [0, N] x [0, N]
    let i = int(N.float32 * (pos.x + size / 2) / size)
    let j = int(N.float32 * (pos.y + size / 2) / size)

    if i < 0 or i >= N or j < 0 or j >= N:
      continue

    let index = j * N + i

    if dir.z < 0: mcml.diffuse[index] += weight
    else: mcml.transmittance[index] += weight

  mcml.slab.material.photons += photons.uint32

  mcml.slab.material.transmittance.update(mcml.transmittance)
  mcml.slab.material.diffuse.update(mcml.diffuse)

let kea = init(
  width = 800, 
  height = 600, 
  title = "mcml",
  cursor = Disabled
)

var mcml = kea.add(
  resolution = 512,
  depth = 0.03'f,
  transform = transform.new(
    y = 1,
    yaw = PI / 2
  ),
  absorption = 2'f,
  scattering = 3'f,
  anisotropy = 0.75'f,
  size = 0.5'f
)

var orbit = orbit.new(
  camera.new(Perspective),
  target = [0.0'f, 1.0, 0.0], 
  distance = 1.0
)

randomize()

for frame in kea.frames:
  mcml.update(photons = 10_000)

  orbit.update(frame)

  frame.backbuffer.clear(color = White * 0.1)

  mcml.render(frame.backbuffer, orbit.camera)

  frame.present()
