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

    // Alpha :: -> Getting strange overlap on alphas + it's blending with background brown, not env on floor

    finalColor = vec4(0.0, 0.0, 0.0, 0.85);
    // finalColor = vec4(0.0, 0.0, 0.0, 0.55);
    // finalColor = vec4(0.0, 0.0, 0.0, 0.25);
    // finalColor = vec4(0.0, 0.0, 0.0, 0.10);
    // 
    // background with a lower 'value'
    // finalColor = vec4(.38, .22, .2, 1);
    //
    // Black :: It looks a bit harsh
    // finalColor = vec4(0.0, 0.0, 0.0, 1);
}
