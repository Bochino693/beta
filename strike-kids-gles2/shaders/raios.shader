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

void vertex() {
	float r = COLOR.g;
	vec3 c = mix(cor_b.rgb, cor_a.rgb, COLOR.r);
	c *= 1.12 - 0.35 * r;
	c += vec3(1.0, 0.95, 0.8) * (0.3 + 0.12 * pulso) * clamp(1.0 - r * 2.2, 0.0, 1.0);
	cor = c;
}

void fragment() {
	ALBEDO = cor;
}
