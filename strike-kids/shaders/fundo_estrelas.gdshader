shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// FUNDO ATRÁS DOS PINOS: veludo roxo-escuro com estrelinhas piscando.
// O fundo escuro faz os pinos brancos saltarem na tela.

uniform vec3 cor_a : source_color = vec3(0.02, 0.06, 0.16);
uniform vec3 cor_b : source_color = vec3(0.05, 0.16, 0.38);
uniform float fase = 0.0;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * vec2(6.0, 3.0);
	vec3 c = mix(cor_b, cor_a, UV.y);
	vec2 cel = floor(uv * 3.0);
	vec2 f = fract(uv * 3.0) - 0.5;
	float r = h(cel);
	if (r > 0.6) {
		float pis = 0.5 + 0.5 * sin(fase * 6.2831 * (0.5 + r) + r * 40.0);
		float est = max(0.0, 1.0 - length(f * vec2(1.0, 1.0)) * 7.0);
		float cruz = max(0.0, 1.0 - abs(f.x) * 30.0) * max(0.0, 1.0 - abs(f.y) * 4.0)
			+ max(0.0, 1.0 - abs(f.y) * 30.0) * max(0.0, 1.0 - abs(f.x) * 4.0);
		c += vec3(0.9, 0.95, 1.0) * (est * 1.5 + cruz * 0.8) * pis;
	}
	ALBEDO = c;
}
