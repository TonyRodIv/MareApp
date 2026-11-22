#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_max_radius;
uniform float u_direction; // 0.0 = top -> bottom (top bar), 1.0 = bottom -> top (bottom navbar)
uniform float u_band_px;   // altura real do widget ProgressiveBlur em pixels físicos
uniform sampler2D u_texture;

out vec4 frag_color;

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = frag / u_size;

    // No Impeller, BackdropFilter entrega a textura da tela inteira em u_size.
    // Calculamos o progresso (0 na borda interna -> 1 na borda externa) sobre
    // a faixa exata de u_band_px para que o blur chegue a 0px reais na borda.
    float band = max(min(u_band_px, u_size.y), 1.0);
    float t;
    if (u_direction < 0.5) {
        t = 1.0 - (frag.y / band);
    } else {
        t = (frag.y - (u_size.y - band)) / band;
    }
    t = clamp(t, 0.0, 1.0);

    // Curva cúbica suave para transição imperceptível a partir de 0px.
    float radius = u_max_radius * t * t * t;

    vec2 sample_uv = uv;
    #ifdef IMPELLER_TARGET_OPENGLES
    sample_uv.y = 1.0 - sample_uv.y;
    #endif

    vec4 sharp = texture(u_texture, sample_uv);
    if (radius < 0.08) {
        frag_color = sharp;
        return;
    }

    // Amostragem em disco de Vogel (16 amostras em espiral áurea):
    // 1 única passagem na GPU, sem linhas de degrau e 100% progressivo por pixel.
    const float GOLDEN_ANGLE = 2.39996323;
    const int SAMPLES = 16;

    vec4 acc = sharp;
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

    vec4 blurred = acc / total_weight;
    // Mistura suave na zona inicial para eliminar qualquer linha de transição.
    float blend = smoothstep(0.0, 0.22, t);
    frag_color = mix(sharp, blurred, blend);
}
