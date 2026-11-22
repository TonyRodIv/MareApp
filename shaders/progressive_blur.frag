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

    // Curva suave (t^1.5): estende o blur mais para baixo com presença real,
    // chegando a 0px exatos na borda interna sem corte brusco.
    float radius = u_max_radius * pow(t, 1.5);

    vec2 sample_uv = uv;
    #ifdef IMPELLER_TARGET_OPENGLES
    sample_uv.y = 1.0 - sample_uv.y;
    #endif

    vec4 sharp = texture(u_texture, sample_uv);
    if (radius < 0.15) {
        frag_color = sharp;
        return;
    }

    // Amostragem em disco de Vogel (32 amostras) com rotação por pixel via
    // Interleaved Gradient Noise e peso gaussiano: blur cremoso e forte
    // sem anéis/pontos fantasmas, mantendo 120fps fluidos ao rolar ou trocar abas.
    const float GOLDEN_ANGLE = 2.39996323;
    const int SAMPLES = 32;

    float ign = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
    float angle_offset = ign * 6.2831853;

    vec4 acc = sharp;
    float total_weight = 1.0;

    for (int i = 1; i <= SAMPLES; i++) {
        float fi = float(i) / float(SAMPLES);
        float r = sqrt(fi) * radius;
        float theta = float(i) * GOLDEN_ANGLE + angle_offset;
        vec2 offset = vec2(cos(theta), sin(theta)) * r / u_size;
        vec2 p = clamp(sample_uv + offset, vec2(0.001), vec2(0.999));
        float w = exp(-fi * 2.8);
        acc += texture(u_texture, p) * w;
        total_weight += w;
    }

    vec4 blurred = acc / total_weight;
    float blend = smoothstep(0.0, 0.14, t);
    frag_color = mix(sharp, blurred, blend);
}
