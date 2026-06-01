#include <metal_stdlib>
using namespace metal;

struct GrainUniforms {
    float2 size;
    float time;
    float opacity;
};

static float grain_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

fragment float4 grain_noise_fragment(float4 position [[position]],
                                     constant GrainUniforms& u [[buffer(0)]]) {
    float2 uv = position.xy / max(u.size, float2(1.0));
    float2 drift = float2(u.time * 0.0003, -u.time * 0.00021);
    float n = grain_hash(floor((uv + drift) * u.size));
    return float4(float3(n), u.opacity * (0.45 + n * 0.8));
}
