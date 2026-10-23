shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// TOON LEVE COM TEXTURA (decoração do cenário, versão 6.2): a forma com
// poucos triângulos e o desenho (rostos, pintas, listras) num ATLAS — uma
// textura só com o desenho de todos, assado dos modelos originais
// (tools/modelos_texturizados.py). A luz é a do toon_leve — sol em duas
// faixas, ambiente, borda clara, o que brilha, neblina —, calculada por
// VÉRTICE nas duas faixas; por PIXEL (6.4) só a divisa entre elas (lisa,
// sem seguir os triângulos: veja o toon_leve). O atlas já vem com a cor
// como ela sai na tela com luz 1 (sRGB -> linear, curva do Godot 4 e cor
// viva, as mesmas contas daqui) e com o sombreado dos cantinhos assado:
// por pixel sobra 1 leitura, 1 clamp e 2 contas. As peças de uma cor só
// apontam o UV para um quadradinho branco do atlas e a cor delas vem do
// vértice (nas de desenho o vértice é branco): todas com o mesmo material,
// o Lote junta as paradas num desenho só.

uniform sampler2D textura : hint_white;
uniform vec4 tinta : hint_color = vec4(1.0);
uniform float faixa : hint_range(0.0, 0.5) = 0.1;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform vec4 cor_borda : hint_color = vec4(1.0, 0.95, 0.9, 1.0);
// o que soma por cima, JÁ como sai na tela (sem conta por vértice)
uniform vec4 emissao : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float brilho_luz : hint_range(0.0, 4.0) = 1.4;
uniform vec3 sol_dir = vec3(0.35, 0.79, 0.5);
uniform vec3 sol_cor = vec3(1.0);
uniform vec3 ambiente = vec3(0.4);
uniform vec3 neblina_cor = vec3(0.7, 0.8, 0.95);
// a cor da neblina como sai na tela: tela_g4(neblina_cor), feita na CPU
// (Temas.luz) — uma conta a menos em cada vértice
uniform vec3 neblina_tela = vec3(0.79, 0.9, 1.0);
uniform float neblina_densidade = 0.0;

varying vec3 fator_sol;
varying vec3 fator_sombra;
varying float virada;
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

// a cor de referência (um tom médio) com que a luz vira fator, e ela na
// tela (tela_g4(MEIO), já calculado: o compilador da Mali não faz sozinho)
const vec3 MEIO = vec3(0.25);
const float TELA_MEIO = 0.283332;
// o branco como sai na tela com luz 1: tela_g4(vec3(1.0))
const float BRANCO = 0.97551;

void vertex() {
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ate_camera = CAMERA_MATRIX[3].xyz - (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = normalize(ate_camera);
	float neblina = 1.0 - exp(-neblina_densidade * length(ate_camera));
	// a divisa já como rampa de 0 (sombra) a 1 (sol) na largura da faixa:
	// conta linear, então a interpolação entre os vértices não muda nada e
	// por pixel sobra só o clamp
	virada = (dot(n, sol_dir) - 0.02) * (0.5 / faixa) + 0.5;
	float rim = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	float acesa = 1.0 - clamp(abs(COLOR.a - 0.5) * 5.0, 0.0, 1.0);
	// a luz que multiplica a cor: sol (ou só o mínimo, na sombra), ambiente,
	// borda clara e o que brilha
	vec3 resto = ambiente + s2l(cor_borda.rgb) * borda * rim * rim * rim + vec3(acesa * brilho_luz);
	vec3 tin = MEIO * s2l(tinta.rgb);
	// a cor do vértice como sai na tela, relativa ao branco (1 nas de desenho)
	vec3 k = tela_g4(s2l(COLOR.rgb)) * ((1.0 - neblina) / (BRANCO * TELA_MEIO));
	fator_sol = tela_g4(tin * (resto + sol_cor)) * k;
	fator_sombra = tela_g4(tin * (resto + sol_cor * luz_minima)) * k;
	soma = emissao.rgb * (1.0 - neblina) + neblina_tela * neblina;
}

void fragment() {
	ALBEDO = texture(textura, UV).rgb * mix(fator_sombra, fator_sol, clamp(virada, 0.0, 1.0)) + soma;
}
