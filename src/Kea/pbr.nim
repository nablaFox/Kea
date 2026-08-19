import renderer, mesh, math, ltc, texture

const 
  PbrVert* = """
uniform mat4 view;
uniform mat4 proj;

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

const
  PbrFrag = """
in vec3 WorldPos;
in vec3 Normal;

uniform vec3 eye;
uniform vec3 albedo;
uniform float metallic;
uniform float roughness;

layout(bindless_sampler)
uniform sampler2D ltcInverseMatrixLut;

layout(bindless_sampler)
uniform sampler2D ltcMagnitudeFresnelLut;

struct RectLight {
  vec3 position; // center
  mat3 rotation;
  float width;
  float height;
  vec3 radiance;
};

uniform RectLight light;

out vec4 FragColor;

struct Polygon {
  vec3 vertices[5];
  int count;
};

Polygon clipAgainstHorizon(vec3 vertices[4]) {
  Polygon clipped;
  clipped.count = 0;

  for (int i = 0; i < 4; ++i) {
    vec3 a = vertices[i];
    vec3 b = vertices[(i + 1) % 4];

    bool aInside = a.z > 0.0;
    bool bInside = b.z > 0.0;

    if (aInside) {
      clipped.vertices[clipped.count++] = a;
    }

    if (aInside != bInside) {
      float t = a.z / (a.z - b.z);
      clipped.vertices[clipped.count++] = mix(a, b, t);
    }
  }

  return clipped;
}

vec3[4] lightCorners(RectLight light) {
  vec3 right = light.rotation * vec3(-1.0, 0.0, 0.0);
  vec3 up = light.rotation * vec3(0.0, 1.0, 0.0);

  vec3 x = right * (light.width / 2.0);
  vec3 y = up * (light.height / 2.0);
  vec3 center = light.position;

  return vec3[4](
    center - y - x,
    center + x - y,
    center + x + y,
    center - x + y 
  );
}

vec2 texelCenteredCoordinates(float x, float y) {
  vec2 size = vec2(textureSize(ltcInverseMatrixLut, 0));
  return (vec2(x, y) * (size - 1.0) + 0.5) / size;
}

vec3 stableTangentToward(vec3 V, vec3 N) {
  vec3 T = V - N * dot(V, N);
  float lengthSquared = dot(T, T);

  if (lengthSquared > 1e-10) {
    return T * inversesqrt(lengthSquared);
  }

  vec3 helper =
    abs(N.z) < 0.999
      ? vec3(0.0, 0.0, 1.0)
      : vec3(0.0, 1.0, 0.0);

  return normalize(cross(helper, N));
}

float edgeIntegral(vec3 v1, vec3 v2) {
  float x = dot(v1, v2);
  float y = abs(x);

  float a = 0.8543985 + (0.4965155 + 0.0145206 * y) * y;
  float b = 3.4175940 + (4.1616724 + y) * y;

  float theta_sintheta = a / b;

  if (x <= 0.0) {
    theta_sintheta = 0.5 * inversesqrt(max(1.0 - x * x, 1e-7)) - theta_sintheta;
  }

  return cross(v1, v2).z * theta_sintheta;
}

float integrateRect(vec3 P, vec3 N, vec3 V, vec3 corners[4], mat3 inverseLtc) {
  vec3 tangent = stableTangentToward(V, N);
  vec3 bitangent = cross(N, tangent);

  mat3 worldToSurface = transpose(mat3(tangent, bitangent, N));

  vec3 cosineCorners[4];

  for (int i = 0; i < 4; i++) {
    cosineCorners[i] = inverseLtc * worldToSurface * (corners[i] - P);
  }

  Polygon polygon = clipAgainstHorizon(cosineCorners);

  if (polygon.count < 3) {
    return 0.0;
  }

  for (int i = 0; i < polygon.count; i++) {
    polygon.vertices[i] = normalize(polygon.vertices[i]);
  }

  float integral = 0.0;

  for (int i = 0; i < polygon.count; i++) {
    vec3 v1 = polygon.vertices[i];
    vec3 v2 = polygon.vertices[(i + 1) % polygon.count];

    integral += edgeIntegral(v1, v2);
  }

  return max(0.0, integral);
}

vec3 rectLight(vec3 P, vec3 N, vec3 V) {
  float NdotV = dot(N, V);

  vec2 uv = texelCenteredCoordinates(
      roughness,
      sqrt(1 - clamp(NdotV, 0, 1))
  );

  vec4 shape = texture(ltcInverseMatrixLut, uv);
  vec2 terms = texture(ltcMagnitudeFresnelLut, uv).xy;

  vec3 F0 = mix(vec3(0.04), albedo, metallic);

  vec3 specularScale = F0 * terms.x + (1 - F0) * terms.y;

  vec3 corners[4] = lightCorners(light);

  mat3 inverseTransform = mat3(
    shape.x, 0, shape.y,
    0, 1, 0,
    shape.z, 0, shape.w
  );

  float specularIntegral = integrateRect(
    P, N, V,
    corners,
    inverseTransform
  );

  float diffuseIntegral = integrateRect(
    P, N, V,
    corners,
    mat3(1.0)
  );

  vec3 specular = specularScale * specularIntegral;

  vec3 diffuseColor = albedo * (1.0 - metallic);
  vec3 diffuse = diffuseColor * diffuseIntegral;

  return light.radiance * (specular + diffuse);
}

void main() {
  vec3 P = WorldPos;
  vec3 V = normalize(eye - P);

  vec3 N = normalize(Normal);
  N = faceforward(N, -V, N);

  vec3 ambient = vec3(0.03) * albedo;
  vec3 color = ambient + rectLight(P, N, V);

  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0 / 2.2));

  FragColor = vec4(color, 1.0);
}
"""

type RectLight* = object
  position*: Vec3
  rotation*: Mat3 = Identity3
  width*: float32 = 1.0
  height*: float32 = 1.0
  radiance*: Vec3

type PBRMaterial* = tuple[
  albedo: Vec3,
  roughness: float32,
  metallic: float32,
]

type PBRGlobals* = tuple[
  view: Mat4,
  proj: Mat4,
  eye: Vec3,
  light: RectLight,
  ltcInverseMatrixLut: ColorTexture,
  ltcMagnitudeFresnelLut: ColorTexture,
]

type PBRRenderer* = Renderer[PBRGlobals, PBRMaterial]

proc new*(storage: MeshStorage): PBRRenderer = 
  let ltcInverseMatrixLut = texture.new(
    ltc.InverseMatrixData,
    ltc.LutSize,
    ltc.LutSize,
    Rgba32Float,
    LinearTextureOptions
  )

  let ltcMagnitudeFresnelLut = texture.new(
    ltc.MagnitudeFresnelData,
    ltc.LutSize,
    ltc.LutSize,
    Rg32Float,
    LinearTextureOptions
  )

  result = renderer.new[PBRGlobals, PBRMaterial](
    storage,
    vert = PbrVert,
    frag = PbrFrag, 
  )

  result.ltcInverseMatrixLut = ltcInverseMatrixLut

  result.ltcMagnitudeFresnelLut = ltcMagnitudeFresnelLut

const Red*: PBRMaterial = (
  albedo: [1.0, 0.0, 0.0],
  roughness: 0.5,
  metallic: 0.0
)

const White*: PBRMaterial = (
  albedo: [1.0, 1.0, 1.0],
  roughness: 0.5,
  metallic: 0.0
)
