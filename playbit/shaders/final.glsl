#pragma language glsl3

extern vec4 white = vec4(1, 1, 1, 1);
extern vec4 black = vec4(0, 0, 0, 1);

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords)
{
    vec4 inColor = Texel(tex, tex_coords) * color;

    vec4 outColor;
    outColor.rgb = mix(black.rgb, white.rgb, inColor.r);
    outColor.a   = 1;

    return outColor;
}