shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// ARCO DO PORTAL (em cima do letreiro, no fim da pista): raios de sol
// alternando duas cores do cenário a partir do centro, com um brilho no
// meio e um filete escuro na borda — o "letreiro de parque" que fecha o
// fundo da pista. Sem textura: nítido em qualquer resolução.

uniform vec3 cor_a : source_color = vec3(1.0, 0.76, 0.1);
uniform vec3 cor_b : source_color = vec3(0.91, 0.22, 0.31);
uniform vec2 centro = vec2(0.0, 2.2);      // de onde saem os raios (metros, no plano XY)
uniform float raios = 22.0;
uniform float giro = 0.0;                  // gira devagar (vem da CPU)

varying vec3 pl;

void vertex() {
	pl = VERTEX;
}

void fragment() {
	vec2 p = pl.xy - centro;
	float a = atan(p.y, p.x) + giro;
	float s = sin(a * raios * 0.5);
	// borda suave entre os raios (sem serrilhado)
	float w = fwidth(s) * 1.5;
	float k = smoothstep(-w, w, s);
	vec3 c = mix(cor_b, cor_a, k);
	float r = length(p);
	// brilho perto do centro e escurecendo para a borda
	c *= 1.12 - 0.35 * smoothstep(0.2, 2.2, r);
	c += vec3(1.0, 0.95, 0.8) * 0.35 * (1.0 - smoothstep(0.0, 0.9, r));
	// a lateral do arco (fora da frente) fica mais escura
	float frente = clamp(NORMAL.z, 0.0, 1.0);
	ALBEDO = c * mix(0.55, 1.0, frente);
}
