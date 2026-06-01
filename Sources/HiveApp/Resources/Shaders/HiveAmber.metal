#include <metal_stdlib>
using namespace metal;

static float hiveHash(float2 p, float seed) {
    return fract(sin(dot(p + seed, float2(127.1, 311.7))) * 43758.5453123);
}

[[ stitchable ]] half4 hiveAmber(float2 position, half4 currentColor, float2 size, float seed, float freshness, float volume) {
    float2 uv = position / max(size, float2(1.0));
    float2 centered = uv - float2(0.5);
    float radial = length(centered);
    float edge = smoothstep(0.30, 0.50, radial);
    float innerCatch = smoothstep(0.34, 0.28, abs(radial - 0.36));
    float grain = hiveHash(floor(position * 0.72), seed) * 0.08;
    float warmth = clamp(freshness, 0.0, 1.0);
    float density = clamp(volume, 0.0, 1.0);

    half3 amber = half3(0.88h + half(warmth) * 0.10h, 0.48h + half(density) * 0.18h, 0.10h);
    half3 murk = half3(0.10h, 0.09h, 0.07h);
    half3 wax = half3(0.96h, 0.77h, 0.32h);
    half3 color = mix(amber, murk, half(edge * 0.42 + radial * 0.18));
    color = mix(color, wax, half(innerCatch * 0.35));
    color += half3(half(grain));

    return half4(mix(currentColor.rgb, color, 0.62h), currentColor.a);
}
