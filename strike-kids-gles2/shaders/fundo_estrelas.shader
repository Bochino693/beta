shader_type spatial;
render_mode unshaded, cull_back;

// FUNDO ATRÁS DOS PINOS: cortina de veludo nas cores do cenário, com um
// HALO de luz atrás dos pinos, estrelinhas piscando e as pregas iluminadas
// pela normal. Edição OpenGL ES 2.0: o sorteio das estrelinhas usa números
// pequenos (a Mali-400 faz a conta de pixel em meia precisão) e as pregas
// são iluminadas por vértice.

uniform vec4 cor_a : hint_color = vec4(0.10, 0.12, 0.45, 1.0);   // em cima
uniform vec4 cor_b : hint_color = vec4(0.20, 0.35, 0.85, 1.0);   // embaixo
uniform vec4 cor_halo : hint_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float fase = 0.0;

varying float dobra;

float h(vec2 p) {
	return fract(sin(p.x * 1.731 + p.y * 9.217) * 43.758);
}

void vertex() {
	dobra = 0.72 + 0.45 * clamp(dot(NORMAL, normalize(vec3(0.75, 0.25, 0.6))), 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV * vec2(6.0, 3.0);
	vec3 c = mix(cor_b.rgb, cor_a.rgb, UV.y);
	vec2 q = (UV - vec2(0.5, 0.82)) * vec2(1.25, 1.6);
	float halo = exp(-dot(q, q) * 4.0);
	c = mix(c, cor_halo.rgb, halo * 0.55);
	float faixa = smoothstep(0.92, 1.0, sin(UV.x * 18.0 + fase * 6.2831) * 0.5 + 0.5);
	c += cor_halo.rgb * faixa * 0.08;
	vec2 cel = floor(uv * 3.0);
	vec2 f = fract(uv * 3.0) - 0.5;
	float r = h(cel);
	if (r > 0.62) {
		float pis = 0.5 + 0.5 * sin(fase * 6.2831 * (0.5 + r) + r * 40.0);
		float est = max(0.0, 1.0 - length(f) * 7.0);
		float cruz = max(0.0, 1.0 - abs(f.x) * 30.0) * max(0.0, 1.0 - abs(f.y) * 4.0)
			+ max(0.0, 1.0 - abs(f.y) * 30.0) * max(0.0, 1.0 - abs(f.x) * 4.0);
		c += vec3(1.0, 0.97, 0.9) * (est * 1.3 + cruz * 0.7) * pis * (1.0 - halo * 0.7);
	}
	ALBEDO = c * dobra;
}
