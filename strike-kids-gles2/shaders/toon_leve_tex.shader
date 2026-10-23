shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// TOON LEVE COM TEXTURA (decoração do cenário, versão 6.2): a forma com
// poucos triângulos e o desenho (rostos, pintas, listras) num ATLAS — uma
// textura só com o desenho de todos, assado dos modelos originais
// (tools/modelos_texturizados.py). A luz é a do toon_leve — sol em duas
// faixas, ambiente, borda clara, o que brilha, neblina —, toda calculada
// por VÉRTICE. O atlas já vem com a cor como ela sai na tela com luz 1
// (sRGB -> linear, curva do Godot 4 e cor viva, as mesmas contas daqui):
// por pixel sobra 1 leitura e 1 multiplicação. As peças de uma cor só
// apontam o UV para um quadradinho branco do atlas e a cor delas vem do
// vértice (nas de desenho o vértice é branco): todas com o mesmo material,
// o Lote junta as paradas num desenho só.

uniform sampler2D textura : hint_white;
uniform vec4 tinta : hint_color = vec4(1.0);
uniform float faixa : hint_range(0.0, 0.5) = 0.06;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform vec4 cor_borda : hint_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform vec4 emissao : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float brilho_luz : hint_range(0.0, 4.0) = 1.4;
uniform vec3 sol_dir = vec3(0.35, 0.79, 0.5);
uniform vec3 sol_cor = vec3(1.0);
uniform vec3 ambiente = vec3(0.4);
uniform vec3 neblina_cor = vec3(0.7, 0.8, 0.95);
uniform float neblina_densidade = 0.0;

varying vec3 fator;
varying vec3 soma;

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

// a cor de referência (um tom médio) com que a luz vira fator
const vec3 MEIO = vec3(0.25);
// o branco como sai na tela com luz 1: tela_g4(vec3(1.0))
const float BRANCO = 0.97551;

void vertex() {
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ate_camera = CAMERA_MATRIX[3].xyz - (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = normalize(ate_camera);
	float neblina = 1.0 - exp(-neblina_densidade * length(ate_camera));
	float t = smoothstep(-faixa, faixa, dot(n, sol_dir) - 0.02);
	float rim = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	float acesa = 1.0 - clamp(abs(COLOR.a - 0.5) * 5.0, 0.0, 1.0);
	// a luz que multiplica a cor: sol, ambiente, borda clara e o que brilha
	vec3 luz = ambiente + sol_cor * max(t, luz_minima) + s2l(cor_borda.rgb) * borda * rim * rim * rim
		+ vec3(acesa * brilho_luz);
	vec3 f = tela_g4(MEIO * s2l(tinta.rgb) * luz) / tela_g4(MEIO);
	// a cor do vértice como sai na tela, relativa ao branco (1 nas de desenho)
	vec3 cv = tela_g4(s2l(COLOR.rgb)) / BRANCO;
	fator = f * cv * (1.0 - neblina);
	soma = tela_g4(s2l(emissao.rgb)) * (1.0 - neblina) + tela_g4(neblina_cor) * neblina;
}

void fragment() {
	ALBEDO = texture(textura, UV).rgb * fator + soma;
}
