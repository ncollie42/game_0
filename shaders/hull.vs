#version 330

in vec3 vertexPosition;
in vec3 vertexNormal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform float outlineThickness = .04;

void main()
{
    vec3 expanded = vertexPosition + vertexNormal * outlineThickness;
    gl_Position = projection * view * model * vec4(expanded, 1.0);
}
