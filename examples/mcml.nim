import Kea, std/random

type
  Mcml* = ref object
    resolution: Positive
    absorption: float32
    scattering: float32
    anisotropy: float32
    depth: float32
    size: float32
    photons: uint32
    transmittance: seq[float32]
    diffuse: seq[float32]

proc new*(
  resolution: Natural,
  depth: float32,
  size: float32,
  absorption: float32,
  scattering: float32,
  anisotropy: float32
): Mcml =
  Mcml(
    absorption: absorption,
    scattering: scattering,
    anisotropy: anisotropy,
    depth: depth,
    resolution: resolution,
    size: size,
    transmittance: newSeq[float32](resolution * resolution),
    diffuse: newSeq[float32](resolution * resolution)
  )

proc update*(mcml: Mcml, photons: Natural) =
  let
    N = mcml.resolution
    depth = mcml.depth
    absorption = mcml.absorption
    scattering = mcml.scattering
    anisotropy = mcml.anisotropy
    size = mcml.size

  for i in 0..<photons:
    let (weight, pos, dir) = block:
      var
        weight = 1.0'f
        pos = [0.0'f, 0.0, 0.0]
        dir = [0.0'f, 0.0, 1.0]

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

        let
          phi = 2 * PI * rand(1.0)

          theta = arccos cosTheta.clamp(-1.0'f, 1.0'f)

        dir = dir.rotate(theta, phi).normalize

      (weight: weight, pos: pos, dir: dir)

    # mappping [-size/2, size/2] x [-size/2, size/2] -> [0, N] x [0, N]
    let
      i = int(N.float32 * (pos.x + size / 2) / size)
      j = int(N.float32 * (pos.y + size / 2) / size)

    if i < 0 or i >= N or j < 0 or j >= N:
      continue

    let index = j * N + i

    if dir.z < 0: mcml.diffuse[index] += weight
    else: mcml.transmittance[index] += weight

  mcml.photons += photons.uint32

proc draws*(mcml: Mcml, res: Resources): seq[PBRDraw] =
  proc emissive(
    frag: Frag,
    transmittance: Texture[R32Float],
    diffuse: Texture[R32Float],
    photons: uint32,
    size: float32
  ): Color =
    proc density(tex: Texture[R32Float], uv: Vec2): float32 =
      let
        res = tex.size
        texelArea = (size / res.x.float32) *
          (size / res.y.float32)

      tex.sample(uv).r / (photons.float32 * texelArea)

    if frag.objectNormal.x > 0.99:
      [0.20'f, 0.65, 0.95] * transmittance.density(frag.uv)

    elif frag.objectNormal.x < -0.99:
      [0.35'f, 0.55, 1.0] * diffuse.density(frag.uv)

    else:
      Black

  result.add draw(
    res.mesh(Cube),
    transform = transform.new(
      rotation = (-PI / 2).yaw,
      scale = 5'f * [
        mcml.depth,
        mcml.size,
        mcml.size
      ]
    ),
    renderer = res.hooks(
      emissive = emissive
    ),
    material = material.new(
      albedo = Black,
      roughness = 0.15'f,
      metallic = 0.0'f,

      transmittance = res.texture(
        key = "mcml/transmittance",
        data = mcml.transmittance,
        width = mcml.resolution,
        height = mcml.resolution,
        format = R32Float,
        DataTextureOptions
      ),

      diffuse = res.texture(
        key = "mcml/diffuse",
        data = mcml.diffuse,
        width = mcml.resolution,
        height = mcml.resolution,
        format = R32Float,
        DataTextureOptions
      ),

      photons = mcml.photons,

      size = mcml.size
    )
  )

when isMainModule:
  let
    kea = init(
      title = "mcml",
      width = 800,
      height = 600,
      cursor = Disabled
    )

    res = resources.new(kea)

    pbr = pbr.new(res)

    mcml = new(
      resolution = 512,
      depth = 0.03'f,
      absorption = 2'f,
      scattering = 3'f,
      anisotropy = 0.75'f,
      size = 0.5'f
    )

    orbit = orbit.new(
      camera.new(Perspective),
      target = [0.0'f, 0.0, 0.0],
      distance = 10.0
    )

  random.randomize()

  for frame in kea.frames:
    if frame.keyboard.pressed(Escape):
      break

    orbit.update(frame)

    mcml.update(photons = 20_000)

    pbr.submit(mcml)

    pbr.render(
      frame.backbuffer,
      orbit.camera,
      RectLight(
        position: [0.0'f, 10.0, 0.0],
        radiance: 0.5 * [10.0'f, 8.0'f, 6.0'f],
        rotation: (PI/2).pitch,
        width: 5.0'f,
        height: 5.0'f
      )
    )

    frame.present()
