import
  math,
  core,
  mesh,
  renderer,
  allocator,
  primitives,
  shader,
  texture as textureModule,
  target as targetModule,
  std/[tables, macros]

type
  CacheEntry[T] = ref object of RootObj
    value: T

  Resources* = ref object
    kea: Kea

    allocator: MeshAllocator

    quad: RenderItem[tuple[]]

    meshes: Table[string, Mesh]
    textures: Table[string, RootRef]
    renderers: Table[string, RootRef]
    targets: Table[string, RootRef]

proc new*(kea: Kea): Resources =
  let allocator = allocator.new(kea)

  Resources(
    kea: kea,
    allocator: allocator,
    quad: item.new(allocator.mesh(Quad))
  )

template cached(
  cache: var Table[string, RootRef],
  key: string,
  create: untyped
): untyped =
  block:
    type T = typeof(create)

    let cacheKey = key
    let entry = cache.getOrDefault(cacheKey)
    var value: T

    if entry == nil:
      value = create
      cache[cacheKey] = CacheEntry[T](value: value)
    else:
      doAssert entry of CacheEntry[T],
        "Resource type mismatch: " & cacheKey

      value = CacheEntry[T](entry).value

    value

template cached[T](
  cache: var Table[string, T],
  key: string,
  create: untyped
): T =
  block:
    let cacheKey = key
    var value = cache.getOrDefault(cacheKey)

    if value == nil:
      value = create
      cache[cacheKey] = value

    value

proc mesh*(
  res: Resources,
  primitive: Primitive,
  cached: bool = true
): Mesh =
  if not cached:
    return res.allocator.mesh(primitive)

  cached(
    res.meshes,
    $primitive,
    res.allocator.mesh(primitive)
  )

proc mesh*(
  res: Resources,
  key: string,
  positions: openArray[Vec3],
  normals: openArray[Vec3],
  indices: openArray[uint32],
  uvs: openArray[Vec2] = [],
  colors: openArray[Vec3] = []
): Mesh =
  let
    vertexCount = positions.len
    indexCount = indices.len

  result = cached(
    res.meshes,
    key,
    mesh.new(
      res.allocator,
      vertexCount,
      indexCount
    )
  )

  doAssert result.vertexCount == vertexCount,
    "Cached mesh vertex count do not match requested"

  doAssert result.indexCount == indexCount,
    "Cached mesh index count do not match requested"

  result.update(
    positions,
    normals,
    colors,
    uvs,
    indices
  )

proc mesh*(
  res: Resources,
  positions: openArray[Vec3],
  normals: openArray[Vec3],
  indices: openArray[uint32],
  uvs: openArray[Vec2] = [],
  colors: openArray[Vec3] = []
): Mesh =
  mesh.new(
    res.allocator,
    positions,
    normals,
    indices,
    uvs,
    colors
  )

proc mesh*(
  res: Resources,
  vertexCount: Natural,
  indexCount: Natural
): Mesh =
  mesh.new(
    res.allocator,
    vertexCount,
    indexCount
  )

proc mesh*(
  res: Resources,
  key: string,
  vertexCount: Natural,
  indexCount: Natural
): Mesh =
  result = cached(
    res.meshes,
    key,
    mesh.new(
      res.allocator,
      vertexCount,
      indexCount
    )
  )

  doAssert result.vertexCount == vertexCount,
    "Cached mesh vertex count do not match requested"

  doAssert result.indexCount == indexCount,
    "Cached mesh index count do not match requested"

proc texture*(
  res: Resources,
  data: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  textureModule.new(
    res.kea,
    data,
    width,
    height,
    format,
    options
  )

proc texture*(
  res: Resources,
  key: string,
  data: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  doAssert data.len > 0
  doAssert data.len == width * height * format.bytesPerPixel,
    "Texture data size does not match texture dimensions"

  result = cached(
    res.textures,
    key,
    textureModule.new(
      res.kea,
      width,
      height,
      format,
      options
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  doAssert result.options == options,
    "Cached texture options do not match requested options"

  result.update(addr data[0])

proc texture*(
  res: Resources,
  data: openArray[float32],
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  textureModule.new(
    res.kea,
    data,
    width,
    height,
    format,
    options
  )

proc texture*(
  res: Resources,
  key: string,
  data: openArray[float32],
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  result = cached(
    res.textures,
    key,
    textureModule.new(
      res.kea,
      width,
      height,
      format,
      options
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  doAssert result.options == options,
    "Cached texture options do not match requested options"

  result.update(data)

proc texture*(
  res: Resources,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  textureModule.new(
    res.kea,
    width,
    height,
    format,
    options
  )

proc texture*(
  res: Resources,
  key: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  result = cached(
    res.textures,
    key,
    textureModule.new(
      res.kea,
      width,
      height,
      format,
      options
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  doAssert result.options == options,
    "Cached texture options do not match requested options"

proc texture*(
  res: Resources,
  data: pointer,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  textureModule.new(
    res.kea,
    data,
    width,
    height,
    format,
    options,
  )

proc texture*(
  res: Resources,
  key: string,
  data: pointer,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  result = cached(
    res.textures,
    key,
    textureModule.new(
      res.kea,
      width,
      height,
      format,
      options,
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  doAssert result.options == options,
    "Cached texture options do not match requested options"

  result.update(data)

macro renderer*(
  res: Resources,
  vert, frag: typed,
  globals: typedesc[tuple] = tuple[]
): untyped =
  result = quote do:
    renderer.new(
      `res`.kea,
      `vert`,
      `frag`,
      `globals`,
    )

macro renderer*(
  res: Resources,
  key: string,
  vert, frag: typed,
  globals: typedesc[tuple] = tuple[]
): untyped =
  result = quote do:
    block:
      let r = cached(
        `res`.renderers,
        `key`,
        renderer.new(
          `res`.kea,
          `vert`,
          `frag`,
          `globals`,
        )
      )

      r

proc renderImpl(
  res, key, destination, vert,
  frag, drawables, uniforms,
  cullMode, depthTest, depthWrite: NimNode
): NimNode {.compileTime.} =
  result = quote do:
    block:
      let
        resourceStore = `res`
        r = resourceStore.renderer(
          `key`,
          `vert`,
          `frag`,
          globals = typeof(`uniforms`)
        )

      r.render(
        `destination`, `drawables`, `uniforms`,
        `cullMode`, `depthTest`, `depthWrite`
      )

macro render*[G, M](
  res: Resources,
  renderer: string,
  target: RenderTarget,
  vert, frag: typed,
  items: seq[RenderItem[M]],
  globals: G,
  cullMode: CullMode = CullDisabled,
  depthTest: DepthTest = DepthLess,
  depthWrite: bool = true
): untyped =
  result = renderImpl(
    res, renderer, target, vert,
    frag, items, globals,
    cullMode, depthTest, depthWrite
  )

macro render*[G, M](
  res: Resources,
  renderer: string,
  target: RenderTarget,
  vert, frag: typed,
  item: RenderItem[M],
  globals: G,
  cullMode: CullMode = CullDisabled,
  depthTest: DepthTest = DepthLess,
  depthWrite: bool = true
): untyped =
  result = renderImpl(
    res, renderer, target, vert,
    frag, item, globals,
    cullMode, depthTest, depthWrite
  )

proc fullscreenVert(vert: Vertex): tuple[pos: Vec4, uv: Vec2] =
  result.pos = vert.position.hom
  result.uv = vert.uv

macro render*[G](
  res: Resources,
  renderer: string,
  target: RenderTarget,
  frag: typed,
  globals: G
): untyped =
  result = quote do:
    block:
      let resourceStore = `res`
      resourceStore.render(
        `renderer`, `target`, fullscreenVert, `frag`,
        resourceStore.quad, `globals`,
        cullMode = CullDisabled,
        depthTest = DepthDisabled,
        depthWrite = false
      )

macro render*[G, M](
  res: Resources,
  renderer: string,
  target: string,
  width, height: Positive,
  vert, frag: typed,
  items: seq[RenderItem[M]],
  globals: G,
  cullMode: CullMode = CullDisabled,
  depthTest: static DepthTest = DepthLess,
  depthWrite: bool = true
): untyped =
  let
    resourceStore = genSym(nskLet, "resourceStore")
    w = genSym(nskLet, "width")
    h = genSym(nskLet, "height")
    testMode = newLit(depthTest)
    attachments = newNimNode(nnkTupleConstr)

  for field in attachmentsType(frag):
    var format: NimNode

    for (typ, candidate) in [
      (bindSym"float32", bindSym"R32Float"),
      (bindSym"Vec2", bindSym"Rg32Float"),
      (bindSym"Vec3", bindSym"Rgb32Float"),
      (bindSym"Vec4", bindSym"Rgba32Float")
    ]:
      if sameType(field[^2], typ):
        format = candidate
        break

    if format == nil:
      error "Unsupported render target output: " & field[^2].repr, field[^2]

    for index in 0 ..< field.len - 2:
      let attachment = quote do:
        textureModule.new(
          `resourceStore`.kea,
          `w`,
          `h`,
          `format`,
          DataTextureOptions
        )

      attachments.add newColonExpr(field[index].strVal.ident, attachment)

  let createTarget = quote do:
    when `testMode` == DepthDisabled:
      targetModule.new(`resourceStore`.kea, `attachments`)
    else:
      targetModule.new(
        `resourceStore`.kea,
        `attachments`,
        textureModule.new(
          `resourceStore`.kea,
          `w`,
          `h`,
          Depth24,
          DataTextureOptions
        )
      )

  result = quote do:
    block:
      let
        `resourceStore` = `res`
        `w` = `width`
        `h` = `height`
        key = `target`

        r = `resourceStore`.renderer(
          `renderer`,
          `vert`,
          `frag`,
          globals = typeof(`globals`)
        )

      var t = cached(`resourceStore`.targets, key, `createTarget`)

      if t.size != (`w`.int32, `h`.int32):
        t = `createTarget`
        `resourceStore`.targets[key] = CacheEntry[typeof(t)](value: t)

      t.clear()
      r.render(t, `items`, `globals`, `cullMode`, `testMode`, `depthWrite`)

      t

macro render*[G](
  res: Resources,
  renderer: string,
  target: string,
  width, height: Positive,
  frag: typed,
  globals: G
): untyped =
  result = quote do:
    block:
      let resourceStore = `res`
      resourceStore.render(
        `renderer`, `target`, `width`, `height`, fullscreenVert, `frag`,
        @[resourceStore.quad], `globals`,
        cullMode = CullDisabled,
        depthTest = DepthDisabled,
        depthWrite = false
      )
