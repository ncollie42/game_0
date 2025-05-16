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
