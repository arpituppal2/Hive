#include <metal_stdlib>
using namespace metal;

fragment float4 frosted_amber_preview_fragment(float4 position [[position]]) {
    float3 base = float3(0.141, 0.118, 0.075);
    float3 amber = float3(0.784, 0.518, 0.102);
    return float4(mix(base, amber, 0.15), 0.96);
}
