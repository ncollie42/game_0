#version 330

// Output fragment color
out vec4 finalColor;

void main()
{
    // Alpha :: -> Getting strange overlap on alphas + it's blending with background brown, not env on floor
    // finalColor = vec4(0.0, 0.0, 0.0, 0.55);
    // finalColor = vec4(0.0, 0.0, 0.0, 0.10);
    // 
    // background with a lower 'value'
    // finalColor = vec4(.38, .22, .2, 1);
    //
    // Black :: It looks a bit harsh
    finalColor = vec4(0.0, 0.0, 0.0, 1);
}
