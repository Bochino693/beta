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


// COR VIVA: realça mais as cores menos saturadas (céu, madeira, chão) e
// quase não mexe nas que já são fortes, com um pouco mais de contraste.
// Era uma passada a mais na tela inteira (tela3d.shader); aqui sai de
// graça, na mesma conta que entrega a cor (as mesmas contas de lá).
vec3 viva(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(lum), c, 1.14 + 0.34 * (1.0 - sat));
	return clamp(c * 1.08 - 0.045, 0.0, 1.0);
}

// a cor CRUA, como o shader do Godot 4 a entregava, até a tela: lá ela
// ainda passava por sRGB -> linear, "filmic" (branco 1,6) e linear -> sRGB
// (medido no Godot 4). Aqui numa conta só, sem potência nem divisão
// (erro < 2%; satura em 1,25, como lá)
vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return viva(x * (1.2094 - x * (0.015 + 0.25 * x)));
}

void vertex() {
	float r = COLOR.g;
	vec3 c = mix(cor_b.rgb, cor_a.rgb, COLOR.r);
	c *= 1.12 - 0.35 * r;
	c += vec3(1.0, 0.95, 0.8) * (0.3 + 0.12 * pulso) * clamp(1.0 - r * 2.2, 0.0, 1.0);
	cor = tela_g4(c);
}

void fragment() {
	ALBEDO = cor;
}
