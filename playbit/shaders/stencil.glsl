// Playdate stencil, inserted into the drawing shaders: pixels are drawn only where the stencil is white.
// The stencil is aligned to the render target, so it does not follow the draw offset.

extern Image stencil;
extern vec2 stencilSize = vec2(1.0, 1.0);
// 0 - no stencil, 1 - image, 2 - tiled image
extern float stencilMode = 0.0;

void stencilTest(vec2 screen_coords)
{
    if (stencilMode == 0.0)
        return;

    vec2 pixel = floor(screen_coords);
    if (stencilMode == 2.0)
        pixel = mod(pixel, stencilSize);
    else if (pixel.x >= stencilSize.x || pixel.y >= stencilSize.y)
        discard;

    vec4 stencilColor = Texel(stencil, (pixel + 0.5) / stencilSize);
    if (stencilColor.r < 0.5 || stencilColor.a < 0.5)
        discard;
}

