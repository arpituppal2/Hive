#include <metal_stdlib>
using namespace metal;

struct WaxPourUniforms {
    float2 size;
    float progress;
    float time;
};

fragment float4 wax_pour_fragment(float4 position [[position]],
                                  constant WaxPourUniforms& u [[buffer(0)]]) {
    float y = 1.0 - position.y / max(u.size.y, 1.0);
    float wave = sin(position.x * 0.035 + u.time * 3.0) * 0.018;
    float fill = smoothstep(u.progress + wave, u.progress + wave - 0.018, y);
    float3 wax = float3(0.784, 0.518, 0.102);
    float3 hot = float3(0.992, 0.671, 0.263);
    return float4(mix(wax, hot, smoothstep(0.0, 0.04, abs(y - u.progress))), fill);
}
