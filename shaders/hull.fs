#version 330 core

uniform vec4 outlineColor;  // Color passed from your application

out vec4 fragColor;

void main()
{
    fragColor = outlineColor;
    // fragColor = vec4{0,0,0,1};
}
