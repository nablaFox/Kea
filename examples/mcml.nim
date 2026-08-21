import Kea, std/[random, sequtils]

type McmlMaterial = tuple[
  transmittance: Texture[R32Float],
  diffuse: Texture[R32Float],
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
    McmlMaterial,
    tuple[color: Vec4]
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
    globals = (
      view: Identity4,
      proj: Identity4
    ),

    vert = proc(
      vertex: Vertex,
      model: Mat4,
      nmat: Mat3,
      material: McmlMaterial,
      g: tuple[view: Mat4, proj: Mat4],
      position: var Vec4,
      output: var tuple[
        objectNormal: Vec3,
        worldNormal: Vec3,
        uv: Vec2
      ]
    ) =
      position = g.proj * g.view * model * vertex.position.hom
      output.objectNormal = vertex.normal
      output.worldNormal = (nmat * vertex.normal).normalize
      output.uv = vertex.uv,

    frag = proc(
      material: McmlMaterial,
      globals: tuple[view: Mat4, proj: Mat4],
      input: tuple[
        objectNormal: Vec3,
        worldNormal: Vec3,
        uv: Vec2
      ],
      atts: var tuple[color: Vec4]
    ) =
      proc density(texture: Texture[R32Float], uv: Vec2): float32 =
        let res = texture.size

        let texelArea =
          (material.size / res.x.float32) *
          (material.size / res.y.float32)

        texture.sample(uv).r / (material.photons.float32 * texelArea)

      let color =
        if input.objectNormal.x > 0.99:
          let color = [0.20'f, 0.65, 0.95]

          let density = material.transmittance.density(input.uv)

          tonemap.exponential(color * density)

        elif input.objectNormal.x < -0.99:
          let color = [0.95'f, 0.65, 0.20] 

          let density = material.diffuse.density(input.uv)

          tonemap.exponential(color * density)

        else:
          let N = input.worldNormal.normalize
          let L = [0.4'f, 0.8, 0.6].normalize

          let ndotl = max(dot(N, L), 0.0)
          let lighting = 0.35 + 0.65 * ndotl

          [0.28'f, 0.42, 0.48] * lighting

      atts.color = color.sRGB.hom
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
