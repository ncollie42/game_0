#version 330

// Output fragment color
out vec4 finalColor;

void main()
{
    // Set shadow color to semi-transparent black
    // Getting issues with overlaping on the alpha, might need to render out solid to a texture and bring back in?
    // finalColor = vec4(0.0, 0.0, 0.0, 0.55);
    // Same as background with a lower 'value'
    finalColor = vec4(.38, .22, .2, 1);
}
