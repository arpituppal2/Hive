#include <metal_stdlib>
using namespace metal;

struct AmberCellUniforms {
    float2 size;
    float age;
    float freshness;
    float opacity;
    uint cell_id;
    float time;
};

static float hive_hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

static float hex_sdf(float2 p, float radius) {
    const float3 k = float3(-0.866025404, 0.5, 0.577350269);
    p = abs(p);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= float2(clamp(p.x, -k.z * radius, k.z * radius), radius);
    return length(p) * sign(p.y);
}

fragment float4 amber_cell_fragment(float4 position [[position]],
                                    constant AmberCellUniforms& u [[buffer(0)]]) {
    float2 uv = position.xy / max(u.size, float2(1.0));
    float2 p = (uv - 0.5) * 2.0;
    float seed = float(u.cell_id);
    float radius = 0.78 + (hive_hash(seed) - 0.5) * 0.025;
    float sdf = hex_sdf(p, radius);
    float inside = 1.0 - smoothstep(0.0, 0.018, sdf);
    float edge = smoothstep(0.18, 0.0, abs(sdf));
    float center = smoothstep(0.0, 0.75, length(p));
    float temp = 1.0 + (hive_hash(seed + 19.0) - 0.5) * 0.10;
    float pulse = (1.0 - u.age) * 0.025 * sin(u.time * 2.4 + seed);

    float3 fresh = float3(0.992, 0.671, 0.263) * temp;
    float3 dormant = float3(0.239, 0.169, 0.122);
    float3 amber = mix(fresh, dormant, clamp(u.age, 0.0, 1.0));
    amber = mix(amber * 0.64, amber, edge * 0.62 + center * 0.18 + pulse);
    float shadow = smoothstep(-0.08, 0.04, sdf) * 0.28;
    amber *= (1.0 - shadow);
    return float4(amber, inside * (u.opacity + (hive_hash(seed + 41.0) - 0.5) * 0.06));
}
