// Fragment shader
#version 330

in vec2 fragTexCoord;
uniform sampler2D texture0;
uniform float tileScale;

out vec4 finalColor;

void main() {
    vec2 tiledUV = fragTexCoord * tileScale;
    finalColor = texture(texture0, tiledUV);
}
