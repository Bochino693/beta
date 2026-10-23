shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// POÇO DO ALÇAPÃO: um poço SEM FUNDO — fica preto com a fundura. (As
// faixas de luz que corriam nas paredes eram linhas finas que piscavam
// com o alçapão aberto: saíram — abriu, caiu, acabou.)

uniform vec4 cor_topo : hint_color = vec4(0.10, 0.20, 0.45, 1.0);
uniform vec4 cor_fundo : hint_color = vec4(0.0, 0.004, 0.02, 1.0);
uniform float y_topo = -0.14;
uniform float y_fundo = -1.75;

varying float fundura;


// COR VIVA: realça mais as cores menos saturadas (céu, madeira, chão) e
// quase não mexe nas que já são fortes, com um pouco mais de contraste.
// Era uma passada a mais na tela inteira (tela3d.shader); aqui sai de
// graça, na mesma conta que entrega a cor (as mesmas contas de lá).
vec3 viva(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(lum), c, 1.08 + 0.32 * (1.0 - sat));
	return clamp(c * 1.07 - 0.035, 0.0, 1.0);
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
	fundura = y_topo - (WORLD_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float t = clamp(fundura / (y_topo - y_fundo), 0.0, 1.0);
	vec3 c = mix(cor_topo.rgb, cor_fundo.rgb, sqrt(t));
	ALBEDO = tela_g4(c);
}
