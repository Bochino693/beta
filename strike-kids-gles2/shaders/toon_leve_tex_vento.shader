shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// TOON LEVE COM TEXTURA E VENTO: o toon_leve_tex.shader (as mesmas contas
// de luz — mexeu num, mexa no outro) com as plantas balançando ao vento
// (palmeiras, samambaias, flores, árvores, algas, corais). O quanto cada
// vértice balança vem pronto no UV2 (Temas._com_vento: x = metros no topo,
// crescendo do pé para cima; y = a rapidez da planta): as plantas paradas
// continuam juntas no Lote (nenhum desenho a mais) e o balanço é só uma
// conta a mais por vértice delas — o resto do cenário usa o shader sem
// vento e não paga nada. A fase sai da posição no mundo: cada planta
// balança no seu tempo e a onda atravessa a planta de leve.

uniform sampler2D textura : hint_white;
uniform vec4 tinta : hint_color = vec4(1.0);
uniform float faixa : hint_range(0.0, 0.5) = 0.1;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform vec4 cor_borda : hint_color = vec4(1.0, 0.95, 0.9, 1.0);
// o que soma por cima, JÁ como sai na tela
uniform vec4 emissao : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float brilho_luz : hint_range(0.0, 4.0) = 1.4;
uniform vec3 sol_dir = vec3(0.35, 0.79, 0.5);
uniform vec3 sol_cor = vec3(1.0);
uniform vec3 ambiente = vec3(0.4);
uniform vec3 neblina_cor = vec3(0.7, 0.8, 0.95);
uniform float neblina_densidade = 0.0;
// prontos na CPU (Temas.luz): a luz do material como sai na tela, relativa
// ao tom médio — no sol, na sombra, o quanto a borda soma em cada uma e a
// das partes que brilham — e a cor da neblina na tela
uniform vec3 f_sol = vec3(1.0);
uniform vec3 f_sombra = vec3(0.5);
uniform vec3 f_borda_sol = vec3(0.0);
uniform vec3 f_borda_sombra = vec3(0.0);
uniform vec3 f_acesa = vec3(2.0);
uniform vec3 neblina_tela = vec3(0.79, 0.9, 1.0);

// (rgb: fator no sol, a: a rampa sol/sombra) e (rgb: fator na sombra, a: neblina)
varying vec4 v_sol;
varying vec4 v_sombra;

vec3 s2l(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 viva(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(lum), c, 1.08 + 0.32 * (1.0 - sat));
	return clamp(c * 1.07 - 0.035, 0.0, 1.0);
}

vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return viva(x * (1.2094 - x * (0.015 + 0.25 * x)));
}

// o branco como sai na tela com luz 1: tela_g4(vec3(1.0))
const float BRANCO = 0.97551;

void vertex() {
	// o vento (o Lote do cenário fica sem giro nem escala: o deslocamento do
	// mundo vale no espaço da malha)
	vec3 mundo = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fase = dot(mundo.xz, vec2(0.31, 0.17));
	float t = TIME * UV2.y;
	VERTEX += vec3(sin(t + fase) + 0.35 * sin(2.3 * t + 1.7 * fase), 0.0, 0.6 * cos(0.8 * t + 1.3 * fase)) * UV2.x;
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ate_camera = CAMERA_MATRIX[3].xyz - (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(ate_camera);
	float neblina = 1.0 - exp(-neblina_densidade * dist);
	float rim = 1.0 - clamp(dot(n, ate_camera) / dist, 0.0, 1.0);
	rim = rim * rim * rim;
	float acesa = 1.0 - clamp(abs(COLOR.a - 0.5) * 5.0, 0.0, 1.0);
	// a cor do vértice como sai na tela, relativa ao branco (1 nas de desenho)
	vec3 k = tela_g4(s2l(COLOR.rgb)) * ((1.0 - neblina) / BRANCO);
	// a divisa já como rampa de 0 (sombra) a 1 (sol) na largura da faixa:
	// conta linear, então a interpolação entre os vértices não muda nada
	float virada = (dot(n, sol_dir) - 0.02) * (0.5 / faixa) + 0.5;
	v_sol = vec4(mix(f_sol + f_borda_sol * rim, f_acesa, acesa) * k, virada);
	v_sombra = vec4(mix(f_sombra + f_borda_sombra * rim, f_acesa, acesa) * k, neblina);
}

void fragment() {
	vec3 f = mix(v_sombra.rgb, v_sol.rgb, clamp(v_sol.a, 0.0, 1.0));
	ALBEDO = texture(textura, UV).rgb * f + mix(emissao.rgb, neblina_tela, v_sombra.a);
}
