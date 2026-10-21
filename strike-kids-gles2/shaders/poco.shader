shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// POÇO DO ALÇAPÃO: fica mais escuro com a fundura e tem faixas de luz nas
// paredes (dão a perspectiva da queda dos pinos).

uniform vec4 cor_topo : hint_color = vec4(0.10, 0.20, 0.45, 1.0);
uniform vec4 cor_fundo : hint_color = vec4(0.0, 0.004, 0.02, 1.0);
uniform vec4 cor_faixa : hint_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float y_topo = -0.14;
uniform float y_fundo = -1.75;
uniform float passo_faixas = 0.3;

varying float fundura;


// a cor CRUA, como o shader do Godot 4 a entregava, até a tela: lá ela
// ainda passava por sRGB -> linear, "filmic" (branco 1,6) e linear -> sRGB
// (medido no Godot 4). Aqui numa conta só, sem potência nem divisão
// (erro < 2%; satura em 1,25, como lá)
vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return x * (1.2094 - x * (0.015 + 0.25 * x));
}

void vertex() {
	fundura = y_topo - (WORLD_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float t = clamp(fundura / (y_topo - y_fundo), 0.0, 1.0);
	vec3 c = mix(cor_topo.rgb, cor_fundo.rgb, sqrt(t));
	float d = abs(fract(fundura / passo_faixas + 0.5) - 0.5) * passo_faixas;
	// borda suave fixa (sem derivadas na OpenGL ES 2)
	float faixa = 1.0 - smoothstep(0.007, 0.012, d);
	faixa *= step(passo_faixas * 0.5, fundura);
	c += cor_faixa.rgb * faixa * (1.0 - t) * (1.0 - t) * 0.9;
	ALBEDO = tela_g4(c);
}
