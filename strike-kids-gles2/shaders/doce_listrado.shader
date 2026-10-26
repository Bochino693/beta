shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// DOCE LISTRADO (os para-choques): listras em espiral pela altura (UV.y,
// contada do começo de cada trecho do tubo: Mundo._tubo_doce) e pela volta
// (UV.x), com a luz do cenário (Materiais.registrar). As contas de luz saem do
// vértice já prontas (no sol e na sombra, com a borda clara) e por PIXEL só
// a divisa sol/sombra (1 clamp e 1 mix) e o brilho (1 smoothstep): o tubo
// fica liso de perto, sem as faixas de cada gomo.

uniform vec4 cor_a : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_b : hint_color = vec4(1.0, 0.23, 0.31, 1.0);
uniform float listras_por_metro = 4.0;
uniform float giro = 1.0;            // voltas da espiral por listra
uniform float faixa : hint_range(0.0, 0.5) = 0.08;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform float especular : hint_range(0.0, 2.0) = 0.5;
uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec3 luz_cor = vec3(1.05, 0.935, 0.745);      // linear (Materiais.definir_luz)
uniform vec3 ambiente = vec3(0.212, 0.278, 0.439);

// (rgb: luz no sol, a: a rampa sol/sombra) e (rgb: luz na sombra, a: o
// cosseno do brilho)
varying vec4 v_sol;
varying vec4 v_sombra;
varying float y_local;

// COR COMO NO GODOT 4: lá o motor já entregava a cor do vértice e as cores
// do material convertidas para luz linear e o shader convertia de novo
// (duas vezes: cores mais fechadas e vivas); e a imagem
// final passava pelo "filmic" (branco 1,6) antes de virar sRGB. As mesmas
// contas aqui, em versões sem potência (baratas na Mali-400/450).
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
	c = mix(vec3(lum), c, 1.14 + 0.34 * (1.0 - sat));
	return clamp(c * 1.08 - 0.045, 0.0, 1.0);
}

vec3 tela(vec3 x) {
	// "filmic" (branco 1,6) + sRGB numa conta só, sem potência (erro < 3%)
	x = max(x, vec3(0.0));
	return viva(min(sqrt(x) * (1.29 - 0.1 * x) / (1.0 + 0.25 * x), vec3(1.0)));
}

vec3 tela_rapida(vec3 x) {
	x = max(x, vec3(0.0));
	return viva(min(sqrt(x) * (1.29 - 0.1 * x) / (1.0 + 0.25 * x), vec3(1.0)));
}

void vertex() {
	y_local = UV.y;
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// a divisa como rampa de 0 (sombra) a 1 (sol) na largura da faixa: conta
	// linear, a interpolação entre os vértices não muda nada
	float virada = (dot(n, normalize(luz_dir)) - 0.02) * (0.5 / faixa) + 0.5;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float r1 = 1.0 - clamp(dot(nv, v), 0.0, 1.0);
	vec3 borda_v = vec3(r1 * r1 * r1 * borda) + ambiente;
	vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
	v_sol = vec4(luz_cor + borda_v, virada);
	v_sombra = vec4(borda_v, dot(nv, normalize(v + lv)));
}

void fragment() {
	float ang = -0.25 - UV.x;
	float s = fract(y_local * listras_por_metro + ang * giro) - 0.5;
	float m = clamp(0.5 - (abs(s) - 0.25) * 30.0, 0.0, 1.0);
	vec3 base = mix(cor_a.rgb, cor_b.rgb, m);
	vec3 luz = mix(v_sombra.rgb, v_sol.rgb, clamp(v_sol.a, 0.0, 1.0));
	vec3 soma = luz_cor * (smoothstep(0.93, 0.95, v_sombra.a) * especular * 0.5);
	ALBEDO = tela_rapida(base * base * luz + soma);
}
