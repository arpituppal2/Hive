#include <metal_stdlib>
using namespace metal;

struct NeuralPathUniforms {
    float base_weight;
    float confidence;
    float node_radius;
    float time;
    float period;
    uint edge_id;
};

static float path_hash(float n) {
    return fract(sin(n * 91.7) * 14375.5453);
}

fragment float4 neural_path_fragment(float4 position [[position]],
                                     float2 texcoord [[user(texturecoord)]],
                                     constant NeuralPathUniforms& u [[buffer(0)]]) {
    float t = clamp(texcoord.x, 0.0, 1.0);
    float taper = u.base_weight * (1.0 - 0.6 * t) * (1.0 - 0.6 * (1.0 - t));
    float center = smoothstep(taper, 0.0, abs(texcoord.y - 0.5));
    float pulse_t = fract(u.time / max(0.1, u.period) + path_hash(float(u.edge_id)));
    float pulse = smoothstep(0.12, 0.0, abs(t - pulse_t));
    float dash = step(0.45, fract((t * 18.0) - u.time * 0.08));
    float certain = step(0.62, u.confidence);
    float visible = mix(dash, 1.0, certain);
    float union_blend = smoothstep(0.0, u.node_radius * 0.4, min(t, 1.0 - t));
    float alpha = center * visible * mix(0.86, 1.0, union_blend) * max(0.18, u.confidence);
    float3 base = float3(0.831, 0.627, 0.090);
    float3 hot = float3(0.992, 0.671, 0.263);
    return float4(mix(base, hot, pulse * 0.75), alpha);
}
