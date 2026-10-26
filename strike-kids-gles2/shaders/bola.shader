shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// BOLA: textura (estrelas / corações) + luz em faixas + brilho de verniz
// (bolinha branca de reflexo) + borda iluminada. Edição OpenGL ES 2.0: a
// luz é calculada por vértice (a esfera tem 32 x 16 gomos), a placa só lê
// a textura.

uniform sampler2D textura : hint_albedo;
uniform float faixa = 0.08;
// borda iluminada mais fraca e quente: a cor da bola (vermelha do Bob,
// laranja da Mia) fica viva até a beirada, sem o véu azulado
uniform float borda = 0.28;
uniform vec4 cor_borda : hint_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float brilho = 1.6;
uniform float aceso : hint_range(0.0, 2.0) = 0.0;
// luz do cenário (Materiais.definir_luz)
uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec3 luz_cor = vec3(1.05, 0.935, 0.745);      // linear (Materiais.definir_luz)
uniform vec3 ambiente = vec3(0.212, 0.278, 0.439);

varying vec3 luz;
varying vec3 soma;
varying float acesa;

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
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = smoothstep(-faixa, faixa, dot(n, normalize(luz_dir)));
	vec3 l = luz_cor * t + ambiente;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float r1 = 1.0 - clamp(dot(nv, v), 0.0, 1.0);
	float rim = r1 * r1 * sqrt(r1);
	vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
	float s = smoothstep(0.94, 0.975, dot(nv, normalize(v + lv)));
	luz = l;
	soma = s2l(cor_borda.rgb) * rim * borda + luz_cor * s * brilho * 0.6;
	acesa = 1.0 + aceso * 0.6;
}

void fragment() {
	vec3 c = texture(textura, UV).rgb;
	ALBEDO = tela_rapida(c * c * luz * acesa + soma);
}
