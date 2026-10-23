shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// TOON LEVE (decoração do cenário): a mesma cara do toon — cor do vértice x
// tinta, luz do sol em duas faixas, ambiente, brilho de borda, partes que
// brilham — calculada por VÉRTICE nas DUAS faixas (a do sol e a da sombra,
// já com a cor pronta). Por PIXEL (6.4) só a passagem de uma para a outra:
// o quanto a pele está virada para o sol vem interpolado e o degradê da
// divisa sai por pixel — a sombra corta a forma numa curva lisa, não
// seguindo os triângulos (os "degraus"). Custa 1 clamp + 1 mix por
// pixel. A luz da cena vem do Mundo (Temas.luz: valores LINEARES); a cor
// sai para a tela com a mesma curva do Godot 4 (a OpenGL ES 2 não converte
// sozinha).

uniform vec4 tinta : hint_color = vec4(1.0);
uniform float faixa : hint_range(0.0, 0.5) = 0.1;
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

varying vec3 cor_sol;
varying vec3 cor_sombra;
varying float virada;

// COR COMO NO GODOT 4 (medido): o shader de lá convertia a cor do vértice e
// as cores do material para luz linear, fazia a luz, e a cor que ele
// entregava AINDA passava por sRGB -> linear e pelo "filmic" (branco 1,6)
// antes de virar sRGB. As mesmas contas aqui, por vértice, em versões sem
// potência (baratas na Mali-400/450).
vec3 s2l(vec3 c) {
	// sRGB -> linear sem potência (polinômio, erro ~1%): barato no vértice
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

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
	vec3 base = s2l(COLOR.rgb) * s2l(tinta.rgb);
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
	vec3 resto = s2l(cor_borda.rgb) * borda * rim * rim * rim * base + s2l(emissao.rgb) + base * acesa * brilho_luz;
	cor_sol = tela_g4(mix(base * (ambiente + sol_cor) + resto, neblina_cor, neblina));
	cor_sombra = tela_g4(mix(base * (ambiente + sol_cor * luz_minima) + resto, neblina_cor, neblina));
}

void fragment() {
	ALBEDO = mix(cor_sombra, cor_sol, clamp(virada, 0.0, 1.0));
}
