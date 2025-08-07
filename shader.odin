package main

FLASH_FS: cstring = `
#version 330

in vec2 fragTexCoord;
in vec4 fragColor; 

uniform sampler2D texture0;
//uniform vec2 flash = vec2(0.0,0.0);
uniform float flash = 0.0;

out vec4 finalColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    finalColor = mix(texelColor, vec4(1.0, 1.0, 1.0, texelColor.a), flash);
}
`

HULL_FS: cstring = `
#version 330 core

uniform vec4 outlineColor;  // Color passed from your application

out vec4 fragColor;

void main()
{
    fragColor = outlineColor;
}
`

HULL_VS: cstring = `
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
`

GRAY_FS: cstring = `
#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord)*colDiffuse*fragColor;

    // Convert texel color to grayscale using NTSC conversion weights
    float gray = dot(texelColor.rgb, vec3(0.299, 0.587, 0.114));

    // Calculate final fragment color
    finalColor = vec4(gray, gray, gray, texelColor.a);
}
`
DISCARD_FS: cstring = `
#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    if (texelColor.a == 0.0) discard;
    finalColor = texelColor * fragColor * colDiffuse;
}
`
SHADOW_FS: cstring = `
#version 330

// Output fragment color
out vec4 finalColor;

void main()
{
    // Using dither to fight the overlapping problem with the alphas.
    // Use screen position to create a dither pattern
    vec2 screenPos = gl_FragCoord.xy;
    float dither = mod(screenPos.x + screenPos.y, 2.0);
    
    // Randomly discard some fragments to reduce overdraw
    if (dither < 0.5) discard;


    finalColor = vec4(0.0, 0.0, 0.0, 0.85);
}
`
SHADOW_VS: cstring = `
#version 330

// Input vertex attributes
in vec3 vertexPosition;

// Input uniform values
uniform mat4 modelMatrix;
uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;

void main()
{
    // Get vertex position
    vec3 vpos = vertexPosition;

    // Transform vertex position to world space
    vec4 mpos = modelMatrix * vec4(vpos, 1.0);

    // Project shadow onto ground plane by offsetting X and Z by Y value
    mpos.x += mpos.y;
    mpos.z += mpos.y;
    // Set Y to almost ground level
    // mpos.y = 1.5 + mpos.y * 0.001; // OG shader was 1.5
    mpos.y = mpos.y * 0.01;

    // Calculate final vertex position
    gl_Position = projectionMatrix * viewMatrix * mpos;
}
`
TILING_FS: cstring = `
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
`
