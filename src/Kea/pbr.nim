import shaders, material, math, camera, drawable, nimgl/[opengl]

const
  VertSource = """
#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 uv;

uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;
uniform mat3 nmat;

out vec3 WorldPos;
out vec3 Normal;

void main() {
  gl_Position = proj * view * model * vec4(position, 1.0);
  WorldPos = vec3(model * vec4(position, 1.0));
  Normal = nmat * normal;
}
"""

  FragSource = """
#version 330 core

in vec3 WorldPos;
in vec3 Normal;

uniform vec3 eye;
uniform vec3 albedo;
uniform float metallic;
uniform float roughness;

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

type PBRShader* = object
  program: GLuint
  model: GLint
  view: GLint
  proj: GLint
  nmat: GLint
  eye: GLint
  roughness: GLint
  metallic: GLint
  albedo: GLint 

proc new*(): PBRShader =
  result.program = createShaderProgram(VertSource, FragSource)

  result.model = glGetUniformLocation(result.program, "model")
  result.view = glGetUniformLocation(result.program, "view")
  result.proj = glGetUniformLocation(result.program, "proj")
  result.nmat = glGetUniformLocation(result.program, "nmat")
  result.eye = glGetUniformLocation(result.program, "eye")
  
  result.albedo = glGetUniformLocation(result.program, "albedo")
  result.roughness = glGetUniformLocation(result.program, "roughness")
  result.metallic = glGetUniformLocation(result.program, "metallic")

proc use*(shader: PBRShader) =
  glUseProgram(shader.program)

proc destroy*(shader: PBRShader) =
  glDeleteProgram(shader.program)

proc bindCamera*(shader: PBRShader, camera: Camera, aspect: float32) =
  let eye = camera.positioned
  let view = camera.view
  let proj = camera.proj(aspect)

  glUniform3fv(shader.eye, 1, addr eye[0])
  glUniformMatrix4fv(shader.view, 1, true, addr view[0][0])
  glUniformMatrix4fv(shader.proj, 1, true, addr proj[0][0])

proc bindDrawable*(shader: PBRShader, drawable: Drawable) =
  let material = drawable.material
  let model = drawable.model

  let nmat: Mat3 = block:
    let m = model.inverse.transpose
    var matrix: Mat3

    for row in 0..<3:
      for col in 0..<3:
        matrix[row][col] = m[row][col]

    matrix

  glUniform3fv(shader.albedo, 1, addr material.albedo[0])
  glUniform1f(shader.roughness, material.roughness)
  glUniform1f(shader.metallic, material.metallic)

  glUniformMatrix3fv(shader.nmat, 1, true, addr nmat[0][0])
  glUniformMatrix4fv(shader.model, 1, true, addr model[0][0])
