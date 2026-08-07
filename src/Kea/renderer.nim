import nimgl/opengl, mesh, shader, transform, math, primitives, target

{.experimental: "dotOperators".}

const VertexHeader = """
#version 330 core
#extension GL_ARB_bindless_texture : enable

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 color;
layout (location = 3) in vec2 uv;

const float PI = 3.14159265359;

uniform mat4 model;
uniform mat3 nmat;
"""

const FragHeader = """
#version 330 core
#extension GL_ARB_bindless_texture : enable

const float PI = 3.14159265359;

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
"""

type
  Renderable* = ref object
    mesh*: Mesh
    transform*: Transform
    topology*: Topology

  RenderItem*[M: tuple] = ref object
    drawable*: Renderable
    material*: M

  RendererObj[G: tuple; M: tuple] = object
    program: GLuint
    items: seq[RenderItem[M]]
    storage: MeshStorage

    globalLocs: seq[GLint]
    materialLocs: seq[GLint]

    modelLoc: GLint
    nmatLoc: GLint

    globals*: G

  Renderer*[G: tuple; M: tuple] = 
    ref RendererObj[G, M]

template `.`*[G, M](r: Renderer[G, M], field: untyped): untyped =
  r.globals.field

template `.=`*[G, M](r: Renderer[G, M], field: untyped, value: untyped) =
  r.globals.field = value

proc `=destroy`[G, M](r: var RendererObj[G, M]) =
  {.cast(raises: []).}:
    if r.program != 0:
      glDeleteProgram(r.program)
      r.program = 0

    r.items = @[]
    r.materialLocs = @[]
    r.globalLocs = @[]
    r.storage = nil

proc new*[G, M](
  storage: MeshStorage, 
  frag: string, 
  vert: string,
  globals = G.default
): Renderer[G, M] = 
  new(result)

  result.program = shader.createProgram(
    vert = VertexHeader & vert, 
    frag = FragHeader & frag
  )

  result.storage = storage

  proc uniformLocations[T: tuple](program: GLuint): seq[GLint] =
    var values: T

    for name, _ in values.fieldPairs:
      result.add glGetUniformLocation(program, name)

  result.globalLocs = uniformLocations[G](result.program)
  result.materialLocs = uniformLocations[M](result.program)

  result.modelLoc = glGetUniformLocation(result.program, "model")
  result.nmatLoc  = glGetUniformLocation(result.program, "nmat")

  result.globals = globals

proc render*[G, M](renderer: Renderer[G, M], target: RenderTarget) = 
  target.use()

  proc bindUniforms[T: tuple](locations: openArray[GLint], values: T) =
    var index = 0

    for _, value in values.fieldPairs:
      setUniform(locations[index], value)
      inc index

  glUseProgram(renderer.program)

  bindUniforms(renderer.globalLocs, renderer.globals)

  for item in renderer.items:
    let drawable = item.drawable
    let model = drawable.transform.model
    let nmat = model.normalMatrix

    setUniform(renderer.modelLoc, model)
    setUniform(renderer.nmatLoc, nmat)

    bindUniforms(renderer.materialLocs, item.material)

    drawable.mesh.draw(topology = drawable.topology)

proc add*[G, M](
  renderer: Renderer[G, M],
  mesh: Mesh,
  material = M.default,
  transform = Identity,
  topology = Triangles,
): RenderItem[M] =
  doAssert mesh != nil, "Cannot add a nil mesh"
  doAssert mesh.storage != nil, "Mesh has no storage"

  let renderable = Renderable(
    mesh: mesh,
    transform: transform,
    topology: topology
  )

  result = RenderItem[M](
    drawable: renderable,
    material: material
  )

  renderer.items.add(result)

proc add*[G, M](
  renderer: Renderer[G, M],
  mesh: Mesh,
  material = M.default,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): RenderItem[M] =
  renderer.add(
    mesh,
    material,
    transform.new(
      x = x,
      y = y,
      z = z,
      pitch = pitch,
      yaw = yaw,
      roll = roll,
      scale = scale
    ),
    topology,
  )

proc add*[G, M](
    renderer: Renderer[G, M],
    primitive: Primitive,
    material = M.default,
    transform = Identity,
    topology = Triangles,
): RenderItem[M] =
  renderer.add(
    primitive.mesh(renderer.storage),
    material,
    transform, 
    topology,
  )

proc add*[G, M](
  renderer: Renderer[G, M],
  primitive: Primitive,
  material = M.default,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): RenderItem[M] =
  renderer.add(
    primitive.mesh(renderer.storage),
    material,
    transform.new(
      x = x,
      y = y,
      z = z,
      pitch = pitch,
      yaw = yaw,
      roll = roll,
      scale = scale
    ),
    topology,
  )

proc transform*(item: RenderItem): var Transform =
  item.drawable.transform

proc position*(item: RenderItem): var Vec3 =
  item.drawable.transform.position

proc positioned*(item: RenderItem): Vec3 =
  let transform = item.drawable.transform
  transform.position

proc scale*(item: RenderItem): var Vec3 =
  item.drawable.transform.scale

proc scaled*(item: RenderItem): Vec3 =
  let transform = item.drawable.transform
  transform.scale

proc rotation*(item: RenderItem): var Mat3 =
  item.drawable.transform.rotation

proc rotated*(item: RenderItem): Mat3 =
  let transform = item.drawable.transform
  transform.rotation

proc model*(item: RenderItem): Mat4 =
  item.drawable.transform.matrix
