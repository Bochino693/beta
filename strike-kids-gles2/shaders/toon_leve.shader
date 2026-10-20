shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// TOON LEVE (decoração do cenário): a mesma cara do toon — cor do vértice x
// tinta, luz do sol em duas faixas, ambiente, brilho de borda, partes que
// brilham — TUDO por VÉRTICE: por pixel sobra só pintar a cor pronta. A luz
// da cena vem do Mundo (Temas.luz: valores LINEARES); a cor sai para a
// tela com a mesma curva do Godot 4 (a OpenGL ES 2 não converte sozinha).

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

varying vec3 cor;

// COR COMO NO GODOT 4: lá o motor já entregava a cor do vértice e as cores
// do material convertidas para luz linear e o shader convertia de novo
// (duas vezes: cores mais fechadas e vivas); e a imagem
// final passava pelo "filmic" (branco 1,6) antes de virar sRGB. As mesmas
// contas aqui (por vértice; no fragmento, a curva aproximada, erro < 3%).
vec3 s2l(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 tela(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 f = clamp(((x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.6) + 0.06) - 0.033333) / 0.68495, 0.0, 1.0);
	return mix(f * 12.92, 1.055 * pow(f, vec3(0.416667)) - 0.055, step(vec3(0.0031308), f));
}

vec3 tela_rapida(vec3 x) {
	x = max(x, vec3(0.0));
	return min(sqrt(x) * (1.29 - 0.1 * x) / (1.0 + 0.25 * x), vec3(1.0));
}

void vertex() {
	vec3 base = s2l(s2l(COLOR.rgb)) * s2l(s2l(tinta.rgb));
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ate_camera = CAMERA_MATRIX[3].xyz - (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = normalize(ate_camera);
	float neblina = 1.0 - exp(-neblina_densidade * length(ate_camera));
	float t = smoothstep(-faixa, faixa, dot(n, sol_dir) - 0.02);
	vec3 c = base * (ambiente + sol_cor * max(t, luz_minima));
	float rim = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	float acesa = 1.0 - clamp(abs(COLOR.a - 0.5) * 5.0, 0.0, 1.0);
	c += s2l(s2l(cor_borda.rgb)) * borda * rim * rim * rim * base + s2l(s2l(emissao.rgb)) + base * acesa * brilho_luz;
	cor = tela(mix(c, neblina_cor, neblina));
}

void fragment() {
	ALBEDO = cor;
}
