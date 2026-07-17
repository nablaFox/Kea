import nimgl/[opengl]

const
  defaultVertSource* = """
     #version 330 core

     layout (location = 0) in vec3 position;
     layout (location = 1) in vec3 normal;
     layout (location = 2) in vec2 uv;

     uniform mat4 model;
     uniform mat4 view;
     uniform mat4 proj;
     uniform mat3 nmat;

     out vec3 FragPos;
     out vec3 Normal;

     void main() {
        gl_Position = proj * view * model * vec4(position, 1.0);
        FragPos = vec3(model * vec4(position, 1.0));
        Normal = nmat * normal;
     }
  """

  defaultFragSource* = """
     #version 330 core

     in vec3 FragPos;
     in vec3 Normal;

     out vec4 FragColor;

     void main() {
        FragColor = vec4(1.0, 0.5, 0.2, 1.0);
     }
  """

proc compileShader(kind: GLenum, source: string): GLuint =
  result = glCreateShader(kind)

  let cSource = source.cstring

  glShaderSource(result, 1, addr cSource, nil)
  glCompileShader(result)

  var success: GLint
  glGetShaderiv(result, GL_COMPILE_STATUS, addr success)

  if success == 0:
    var log = newString(512)
    glGetShaderInfoLog(result, 512, nil, log.cstring)
    quit("Shader compilation failed:\n" & log)

proc createShaderProgram*(vert: string, frag: string): GLuint =
  let vertexShader = compileShader(GL_VERTEX_SHADER, vert)
  let fragmentShader = compileShader(GL_FRAGMENT_SHADER, frag)

  result = glCreateProgram()

  glAttachShader(result, vertexShader)
  glAttachShader(result, fragmentShader)
  glLinkProgram(result)
  
  var success: GLint
  glGetProgramiv(result, GL_LINK_STATUS, addr success)
 
  if success == 0:
    var log = newString(512)
    glGetProgramInfoLog(result, 512, nil, log.cstring)
    quit("Shader linking failed:\n" & log)

  glDeleteShader(vertexShader)
  glDeleteShader(fragmentShader)
