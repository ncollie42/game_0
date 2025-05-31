#version 330 core

// Input vertex attributes from your VBOs
layout (location = 0) in vec3 aPos;    // Vertex position (usually location 0)
layout (location = 1) in vec3 aNormal; // Vertex normal (usually location 1 or higher)

// Output to the fragment shader (will be interpolated)
out vec3 vNormal;

// Uniforms for transformations
uniform mat4 model; // Model matrix
uniform mat4 view;  // View matrix (camera position/orientation)
uniform mat4 projection; // Projection matrix (perspective/orthographic)

void main()
{
    // Transform the vertex position into clip space
    gl_Position = projection * view * model * vec4(aPos, 1.0);

    // Transform the normal into world space (or eye space, depending on your lighting model)
    // For directional lights, world space is often sufficient.
    // The normal matrix (inverse transpose of model matrix) is essential for correct normal transformation
    // when non-uniform scaling is applied to the model.
    vNormal = mat3(transpose(inverse(model))) * aNormal;
    // If you know you won't have non-uniform scaling, you can simplify to:
    // vNormal = mat3(model) * aNormal;
}
