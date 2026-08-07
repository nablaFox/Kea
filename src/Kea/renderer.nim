import nimgl/opengl, mesh, shader, transform, math, primitives

const VertexHeader = """
#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 color;
layout (location = 3) in vec2 uv;

const float PI = 3.14159265359;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;
uniform mat3 nmat;

"""

const FragHeader = """
#version 330 core

const float PI = 3.14159265359;

uniform vec3 eye;

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

const DefaultVert* = """
out vec3 WorldPos;
out vec3 Normal;
flat out vec3 Color;

void main() {
  gl_Position = proj * view * model * vec4(position, 1.0);
  WorldPos = vec3(model * vec4(position, 1.0));
  Normal = nmat * normal;
  Color = color;
}
"""

type
  RenderContext* = object
    view*: Mat4
    proj*: Mat4
    eye*: Vec3

  RenderPass* = object
    render*: proc(ctx: RenderContext) {.closure}

  RendererObj[T: tuple] = object
    program: GLuint
    drawables: seq[Drawable[T]]
    storage: MeshStorage

    viewLoc: GLint
    projLoc: GLint
    eyeLoc: GLint
    modelLoc: GLint
    nmatLoc: GLint

    materialLocs: seq[GLint]

  Renderer*[T: tuple] = ref RendererObj[T]

  Drawable*[T: tuple] = ref object
    material*: T
    mesh*: Mesh
    transform*: Transform
    topology*: Topology

proc `=destroy`[T](r: var RendererObj[T]) =
  {.cast(raises: []).}:
    if r.program != 0:
      glDeleteProgram(r.program)
      r.program = 0

    r.drawables = @[]
    r.materialLocs = @[]
    r.storage = nil

proc new*[T](storage: MeshStorage, frag: string, vert = DefaultVert): Renderer[T] = 
  new(result)

  result.program = shader.createProgram(
    vert = VertexHeader & vert, 
    frag = FragHeader & frag
  )

  result.storage = storage

  result.viewLoc  = glGetUniformLocation(result.program, "view")
  result.projLoc  = glGetUniformLocation(result.program, "proj")
  result.eyeLoc   = glGetUniformLocation(result.program, "eye")
  result.modelLoc = glGetUniformLocation(result.program, "model")
  result.nmatLoc  = glGetUniformLocation(result.program, "nmat")

  var material: T

  for name, _ in material.fieldPairs:
    result.materialLocs.add(
      glGetUniformLocation(result.program, name)
    )

proc render*[T](renderer: Renderer[T], ctx: RenderContext) = 
  glUseProgram(renderer.program)

  setUniform(renderer.viewLoc, ctx.view)
  setUniform(renderer.projLoc, ctx.proj)
  setUniform(renderer.eyeLoc, ctx.eye)

  for drawable in renderer.drawables:
    let model = drawable.transform.model
    let nmat = model.normalMatrix

    setUniform(renderer.modelLoc, model)
    setUniform(renderer.nmatLoc, nmat)

    var index = 0

    for _, value in drawable.material.fieldPairs:
      setUniform(renderer.materialLocs[index], value)
      inc index

    drawable.mesh.draw(topology = drawable.topology)

proc add*[T](
  renderer: Renderer[T],
  mesh: Mesh,
  material: T,
  transform = Identity,
  topology = Triangles,
): Drawable[T] =
  doAssert mesh != nil, "Cannot add a nil mesh"
  doAssert mesh.storage != nil, "Mesh has no storage"

  result = Drawable[T](
    mesh: mesh,
    material: material,
    transform: transform,
    topology: topology
  )

  renderer.drawables.add(result)

proc add*[T](
  renderer: Renderer[T],
  mesh: Mesh,
  material: T,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): Drawable[T] =
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

proc add*[T](
    renderer: Renderer[T],
    primitive: Primitive,
    material: T,
    transform = Identity,
    topology = Triangles,
): Drawable[T] =
  renderer.add(
    mesh.new(renderer.storage, primitive), 
    material,
    transform, 
    topology,
  )

proc add*[T](
  renderer: Renderer[T],
  primitive: Primitive,
  material: T,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): Drawable[T] =
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

proc transform*(drawable: Drawable): var Transform =
  drawable.transform

proc position*(drawable: Drawable): var Vec3 =
  drawable.transform.position

proc positioned*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.position

proc scale*(drawable: Drawable): var Vec3 =
  drawable.transform.scale

proc scaled*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.scale

proc rotation*(drawable: Drawable): var Mat3 =
  drawable.transform.rotation

proc rotated*(drawable: Drawable): Mat3 =
  let transform = drawable.transform
  transform.rotation

proc model*(drawable: Drawable): Mat4 =
  drawable.transform.matrix
