shader_type spatial;
render_mode unshaded, cull_back;

// ARCO DO PORTAL (em cima do letreiro, no fim da pista): raios de sol
// alternando duas cores do cenário. Os raios são a própria malha (um leque
// de triângulos: COLOR.r diz a cor do raio, COLOR.g a distância do
// centro) — tudo por vértice: a placa só pinta.

uniform vec4 cor_a : hint_color = vec4(1.0, 0.76, 0.1, 1.0);
uniform vec4 cor_b : hint_color = vec4(0.91, 0.22, 0.31, 1.0);
uniform float pulso = 0.0;      // brilho do centro pulsando (vem da CPU)

varying vec3 cor;


// cor como no Godot 4: s2l = sRGB -> linear; tela = "filmic" (branco 1,6)
// + sRGB (por vértice, exata)
vec3 s2l(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float s2l1(float c) {
	return c < 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

vec3 tela(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 f = clamp(((x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.6) + 0.06) - 0.033333) / 0.68495, 0.0, 1.0);
	return mix(f * 12.92, 1.055 * pow(f, vec3(0.416667)) - 0.055, step(vec3(0.0031308), f));
}

void vertex() {
	float r = s2l1(COLOR.g);
	vec3 c = mix(s2l(cor_b.rgb), s2l(cor_a.rgb), s2l1(COLOR.r));
	c *= 1.12 - 0.35 * r;
	c += vec3(1.0, 0.95, 0.8) * (0.3 + 0.12 * pulso) * clamp(1.0 - r * 2.2, 0.0, 1.0);
	cor = tela(c);
}

void fragment() {
	ALBEDO = cor;
}
