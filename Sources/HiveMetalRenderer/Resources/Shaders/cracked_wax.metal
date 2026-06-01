#include <metal_stdlib>
using namespace metal;

struct CrackUniforms {
    float2 size;
    float time;
};

static float crack_hash(float2 p) {
    return fract(sin(dot(p, float2(41.0, 289.0))) * 58123.0);
}

fragment float4 cracked_wax_fragment(float4 position [[position]],
                                     constant CrackUniforms& u [[buffer(0)]]) {
    float2 p = position.xy / max(u.size, float2(1.0));
    float2 cell = floor(p * 18.0);
    float n = crack_hash(cell);
    float crack = smoothstep(0.48, 0.5, abs(fract(p.x * 18.0 + n) - fract(p.y * 18.0 - n)));
    float3 conflict = float3(0.545, 0.227, 0.165);
    return float4(conflict, crack * 0.55);
}
