import renderer, mesh, math

const
  PbrFrag = """
#version 330 core

in vec3 WorldPos;
in vec3 Normal;

uniform vec3 eye;
uniform vec3 albedo;
uniform float metallic;
uniform float roughness;

uniform sampler2D ltcMatrix;
uniform sampler2D ltcAmplitude;

out vec4 FragColor;

const float PI = 3.14159265359;

// TEMP
vec3 lightPos = vec3(1.5, 1.5, -4.0);
vec3 lightColor = vec3(23.47, 21.31, 20.79);

vec3 fresnelSchlick(vec3 H, vec3 V, vec3 F0) {
  float cosTheta = max(dot(H, V), 0.0);
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float distributionGGX(vec3 N, vec3 H) {
  float a = roughness * roughness;
  float a2 = a * a;

  float NdotH = max(dot(N, H), 0.0);
  float NdotH2 = NdotH * NdotH;

  float denom = NdotH2 * (a2 - 1.0) + 1.0;

  return a2 / max(PI * denom * denom, 0.000001);
}

float geometrySchlickGGX(float cosTheta) {
  float r = (roughness + 1.0);
  float k = (r * r) / 8.0;

  return cosTheta / (cosTheta * (1.0 - k) + k);
}

float geometrySmith(vec3 N, vec3 V, vec3 L) {
  float NdotV = max(dot(N, V), 0.0);
  float NdotL = max(dot(N, L), 0.0);

  float ggx2 = geometrySchlickGGX(NdotV);
  float ggx1 = geometrySchlickGGX(NdotL);

  return ggx1 * ggx2;
}

float computeAttenuation(vec3 lightPos) {
  float distance = length(lightPos - WorldPos);
  return 1 / (distance * distance);
}

void main() {
  vec3 N = normalize(Normal);
  vec3 V = normalize(eye - WorldPos);
  vec3 L = normalize(lightPos - WorldPos);
  vec3 H = normalize(V + L);

  if (!gl_FrontFacing) {
      N = -N;
  }

  float attenuation = computeAttenuation(lightPos);

  vec3 radiance = lightColor * attenuation;

  float D = distributionGGX(N, H);
  float G = geometrySmith(N, V, L);

  vec3 F0 = mix(vec3(0.04), albedo, metallic);
  vec3 F = fresnelSchlick(H, V, F0);

  vec3 ks = F;
  vec3 kd = (vec3(1.0) - F) * (1.0 - metallic);

  vec3 specular = ks * D * G / (4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001);

  vec3 diffuse = kd * albedo / PI;

  vec3 Lo = (specular + diffuse) * radiance * max(dot(N, L), 0.0);

  vec3 ambient = vec3(0.03) * albedo;
  vec3 color = ambient + Lo;

  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0/2.2));

  FragColor = vec4(color, 1.0);
}
"""

type PBRMaterial* = tuple[
  albedo: Vec3,
  roughness: float32,
  metallic: float32,
  # ltcMatrix: GLuint,
  # ltcAmplitude: GLuint
]

type PBRRenderer* = Renderer[PBRMaterial]

proc new*(storage: MeshStorage): PBRRenderer = 
  renderer.new[PBRMaterial](
    frag = PbrFrag, 
    storage,
  )

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
