import Kea, std/random

const N: Natural = 512

let kea = init(
  width = 800, 
  height = 600, 
  title = "mcml"
)

type SlabMaterial = tuple[
  transmittance: ColorTexture,
  diffuse: ColorTexture,
  depth: float32
]

let renderer = kea.newRenderer(
  material = SlabMaterial,
  globals = (
    view: Identity4,
    proj: Identity4
  ),
  vert = """
    uniform mat4 view;
    uniform mat4 proj;
    uniform float depth;

    out vec3 ObjectNormal;
    out vec3 WorldNormal;
    out vec2 UV;

    void main() {
      mat4 depthMat = mat4(1.0);

      depthMat[0][0] = depth;

      gl_Position =
        proj * view * model * depthMat * vec4(position, 1.0);

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

    void main() {
      vec3 color;

      if (ObjectNormal.x > 0.99) {
        float T = texture(transmittance, UV).r;

        vec3 transmissionColor = vec3(0.25, 0.80, 0.65);

        color = transmissionColor * T;
      } else if (ObjectNormal.x < -0.99) {
        float D = texture(diffuse, UV).r;

        vec3 diffuseColor = vec3(0.35, 0.55, 1.0);

        color = diffuseColor * D;
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
      width = N, 
      height = N, 
      format = R32Float,
      DataTextureOptions
    ),
    diffuse: texture.new(
      width = N, 
      height = N, 
      format = R32Float,
      DataTextureOptions
    ),
    depth: 0.05'f
  ),
  yaw = -PI / 2,
  y = 1.0
)

var orbit = orbit.new(
  camera.new(Perspective),
  target = [0.0'f, 1.0, 0.0], 
  distance = 8.0
)

proc mcmlUpdate(
  slab: RenderItem[SlabMaterial], 
  size: float32,
  passes: Natural, 
  photons: Natural,
  absorption: float32,
  scattering: float32,
  anisotropy: float32,
) =
  var transmittance: array[N * N, float32]
  var diffuse: array[N * N, float32]

  let depth = slab.material.depth

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

      dir = dir.rotate(
        arccos(cosTheta.clamp(-1.0'f, 1.0'f)), 
        phi
      ) 

      dir = dir.normalize

    (weight: weight, pos: pos, dir: dir)
    
  for n in 0..<passes:
    for i in 0..<photons:
      let (weight, pos, dir) = photonRandomWalk()

      # mappping [-size/2, size/2] x [-size/2, size/2] -> [0, N] x [0, N]
      let i = int(N.float32 * (pos.x + size / 2) / size)
      let j = int(N.float32 * (pos.y + size / 2) / size)

      if i < 0 or i >= N or j < 0 or j >= N:
        continue

      if dir.z < 0: diffuse[j * N + i] += weight
      else: transmittance[j * N + i] += weight

  for i in 0..<N*N:
    transmittance[i] /= passes.float32
    diffuse[i] /= passes.float32

  slab.material.transmittance.update(transmittance)
  slab.material.diffuse.update(diffuse)

randomize()

slab.mcmlUpdate(
  size = 0.5'f,
  passes = 128, 
  photons = 100_000,
  absorption = 2'f,
  scattering = 3'f,
  anisotropy = 0.75'f
)

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break 

  frame.backbuffer.clear(color = White * 0.1)

  orbit.update(frame)

  renderer.view = orbit.camera.view
  renderer.proj = orbit.camera.proj(frame.backbuffer.aspect)

  renderer.render(frame.backbuffer)

  frame.present()
