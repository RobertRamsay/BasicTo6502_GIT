//
// shd_crt - simple PAL CRT look: curvature, scanlines, aperture mask, soft glow.
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2 u_source_size;   // 384 x 272
uniform float u_curvature;    // 0 = flat, 1 = gentle curve
uniform float u_scanline;     // 0 = none, 1 = full black gaps
uniform float u_mask;         // 0 = none, 1 = strong RGB mask

vec2 curve_uv(vec2 uv)
{
    vec2 c = uv * 2.0 - 1.0;
    vec2 offset = abs(c.yx) / vec2(6.0, 5.0);
    c = c + c * offset * offset * u_curvature;
    return c * 0.5 + 0.5;
}

void main()
{
    vec2 uv = curve_uv(v_vTexcoord);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
    {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 texel = 1.0 / u_source_size;

    // Horizontal softness (analogue bandwidth) plus a little glow
    vec3 col = texture2D(gm_BaseTexture, uv).rgb * 0.56;
    col += texture2D(gm_BaseTexture, uv + vec2(texel.x * 0.6, 0.0)).rgb * 0.22;
    col += texture2D(gm_BaseTexture, uv - vec2(texel.x * 0.6, 0.0)).rgb * 0.22;
    vec3 glow = texture2D(gm_BaseTexture, uv + vec2(texel.x * 1.5, 0.0)).rgb;
    glow += texture2D(gm_BaseTexture, uv - vec2(texel.x * 1.5, 0.0)).rgb;
    col += glow * 0.06;

    // Scanlines: brightest in the middle of each source row
    float row = uv.y * u_source_size.y;
    float beam = sin(fract(row) * 3.14159265);
    col *= mix(1.0 - u_scanline, 1.0, beam);

    // Aperture grille
    float m = mod(gl_FragCoord.x, 3.0);
    vec3 mask = vec3(1.0 - u_mask);
    if (m < 1.0)
    {
        mask.r = 1.0;
    }
    else if (m < 2.0)
    {
        mask.g = 1.0;
    }
    else
    {
        mask.b = 1.0;
    }
    col *= mask;

    // Brightness compensation and vignette
    col *= 1.0 + (u_scanline * 0.45) + (u_mask * 0.3);
    vec2 v = uv * (1.0 - uv);
    float vig = clamp(pow(v.x * v.y * 18.0, 0.18), 0.0, 1.0);
    col *= vig;

    gl_FragColor = vec4(col, 1.0) * v_vColour;
}
