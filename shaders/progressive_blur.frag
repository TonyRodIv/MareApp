#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_max_radius;
uniform float u_direction; // 0.0 = top -> bottom (top bar), 1.0 = bottom -> top (bottom navbar)
uniform sampler2D u_texture;

out vec4 frag_color;

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = frag / u_size;

    // Progresso contínuo de 0 (borda interna sem blur) até 1 (borda externa blur máximo).
    float t = u_direction < 0.5 ? (1.0 - uv.y) : uv.y;
    t = clamp(t, 0.0, 1.0);

    // Curva suave (quadrática) para transição imperceptível de 0px até u_max_radius.
    float radius = u_max_radius * t * t;

    vec2 sample_uv = uv;
    #ifdef IMPELLER_TARGET_OPENGLES
    sample_uv.y = 1.0 - sample_uv.y;
    #endif

    if (radius < 0.35) {
        frag_color = texture(u_texture, sample_uv);
        return;
    }

    // Amostragem em disco de Vogel (16 amostras em espiral áurea):
    // 1 única passagem na GPU, sem linhas de degrau e 100% progressivo por pixel.
    const float GOLDEN_ANGLE = 2.39996323;
    const int SAMPLES = 16;

    vec4 acc = texture(u_texture, sample_uv);
    float total_weight = 1.0;

    for (int i = 1; i <= SAMPLES; i++) {
        float fi = float(i) / float(SAMPLES);
        float r = sqrt(fi) * radius;
        float theta = float(i) * GOLDEN_ANGLE;
        vec2 offset = vec2(cos(theta), sin(theta)) * r / u_size;
        vec2 p = clamp(sample_uv + offset, vec2(0.001), vec2(0.999));
        float w = 1.0 - fi * 0.55;
        acc += texture(u_texture, p) * w;
        total_weight += w;
    }

    frag_color = acc / total_weight;
}
