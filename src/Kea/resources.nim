import
  math,
  core,
  texture as textureModule,
  mesh,
  renderer,
  allocator,
  primitives,
  std/[tables, macros]

type
  CacheEntry[T] = ref object of RootObj
    value: T

  Resources* = ref object
    kea: Kea

    allocator: MeshAllocator

    meshes: Table[string, Mesh]
    textures: Table[string, RootRef]
    renderers: Table[string, RootRef]

proc new*(kea: Kea): Resources =
  Resources(
    kea: kea,
    allocator: allocator.new(kea)
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
  const bytesPerPixel =
    case format
    of Rgba8Linear, Rgba8Srgb, R32Float, Depth24, Depth32Float: 4
    of Rg32Float: 8
    of Rgb32Float: 12
    of Rgba32Float: 16

  doAssert data.len > 0
  doAssert data.len == width * height * bytesPerPixel,
    "Texture data size does not match texture dimensions"

  result = cached(
    res.textures,
    key,
    textureModule.new(
      res.kea,
      nil,
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
      nil,
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
    nil,
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
      nil,
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
      nil,
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

  if data != nil:
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
