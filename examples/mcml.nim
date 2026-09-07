import Kea, std/[random, sequtils]

type 
  Mcml = object
    resolution: Natural
    absorption: float32
    scattering: float32
    anisotropy: float32
    depth: float32
    size: float32
    photons: uint32
    transmittance: seq[float32]
    diffuse: seq[float32]

proc new(
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

proc update(mcml: var Mcml, photons: Natural) = 
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

proc render(
  mcml: Mcml, 
  res: Resources,
  backbuffer: BackBufferTarget, 
  camera: Camera,
  x, y, z: float32 = 0.0,
  yaw, pitch, roll: float32 = 0.0
) = 
  proc vert(
    vert: Vertex,
    model: Mat4, nmat: Mat3,
    view, proj: Mat4
  ): tuple[
    pos: Vec4,
    objectNormal: Vec3,
    worldNormal: Vec3,
    uv: Vec2
  ] =
    result.pos = proj * view * model * vert.position.hom
    result.objectNormal = vert.normal
    result.worldNormal = (nmat * vert.normal).normalize
    result.uv = vert.uv

  proc frag(
    objectNormal: Vec3,
    worldNormal: Vec3,
    uv: Vec2,
    transmittance: Texture[R32Float],
    diffuse: Texture[R32Float],
    photons: uint32,
    size: float32,
  ): tuple[pixel: Vec4] =
    proc density(tex: Texture[R32Float], uv: Vec2): float32 =
      let 
        res = tex.size

        texelArea = (size / res.x.float32) * 
          (size / res.y.float32)

      tex.sample(uv).r / (photons.float32 * texelArea)

    let color =
      if objectNormal.x > 0.99:
        let 
          color = [0.20'f, 0.65, 0.95]

          density = transmittance.density(uv)

        tonemap.exponential(color * density)

      elif objectNormal.x < -0.99:
        let 
          color = [0.95'f, 0.65, 0.20] 

          density = diffuse.density(uv)

        tonemap.exponential(color * density)

      else:
        let 
          N = worldNormal.normalize
          L = [0.4'f, 0.8, 0.6].normalize
          ndotl = max(dot(N, L), 0.0)
          lighting = 0.35 + 0.65 * ndotl

        [0.28'f, 0.42, 0.48] * lighting

    result.pixel = color.sRGB.hom

  let
    transmittance = res.texture(
      "mcml/transmittance",
      data = mcml.transmittance,
      width = resolution, 
      height = resolution, 
      format = R32Float,
      DataTextureOptions
    ) 

    diffuse = res.texture(
      "mcml/diffuse",
      data = mcml.diffuse,
      width = mcml.resolution, 
      height = mcml.resolution, 
      format = R32Float,
      DataTextureOptions
    )

    renderer = res.renderer(
      "mcml/renderer",
      vert = vert,
      frag = frag,
      globals = (
        view: camera.view,
        proj: camera.proj(backbuffer.aspect),
        transmittance: transmittance,
        diffuse: diffuse,
        photons: mcml.photons,
        size: mcml.size
      )
    )

  renderer.render(
    target = backbuffer,
    mesh = res.mesh(Cube),
    x = x,
    y = y,
    z = z,
    yaw = yaw,
    pitch = pitch,
    roll = roll,
    scale = [
      mcml.depth, 
      mcml.size, 
      mcml.size
    ] * 0.5'f
  )

let 
  kea = init(
    title = "mcml",
    width = 800, 
    height = 600, 
    cursor = Disabled
  )

  res = kea.resources

var 
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
    target = [0.0'f, 1.0, 0.0], 
    distance = 1.0
  )

random.randomize()

for frame in kea.frames:
  if frame.keyboard.pressed(Escape):
    break

  orbit.update(frame)

  mcml.update(photons = 10_000)

  frame.backbuffer.clear(color = White * 0.1)

  mcml.render(
    res, 
    frame.backbuffer, 
    orbit.camera,
    yaw = PI / 2.0,
    y = 1.0
  )

  frame.present()
