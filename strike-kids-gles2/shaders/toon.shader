shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// TOON DO STRIKE KIDS — edição OpenGL ES 2.0 (Mali-400/450).
// Cor vem da cor do vértice (sRGB, pintada no modelador). Luz em duas
// faixas (sol / sombra colorida), brilho de borda e, nos rostos, o desenho
// do rosto projetado de frente (atlas de expressões).
// TUDO POR VÉRTICE: a placa só pinta a cor pronta (e, no rosto, uma
// textura). A conta da luz é feita em linear e a cor sai para a tela com a
// mesma curva do Godot 4.

uniform vec4 tinta : hint_color = vec4(1.0);
uniform float faixa : hint_range(0.0, 0.5) = 0.06;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform vec4 cor_borda : hint_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform float especular : hint_range(0.0, 2.0) = 0.0;
uniform float tamanho_especular : hint_range(0.5, 0.999) = 0.92;
uniform vec4 emissao : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// partes que brilham (alfa do vértice = 0.5): núcleo do peito, antena, orelhas
uniform float brilho_luz : hint_range(0.0, 4.0) = 1.4;

uniform bool usa_rosto = false;
uniform sampler2D rosto : hint_albedo;
uniform vec2 rosto_centro = vec2(0.0, 0.235);
uniform vec2 rosto_tamanho = vec2(0.46, 0.40);
uniform vec2 rosto_grade = vec2(4.0, 2.0);
uniform vec2 rosto_celula = vec2(0.0, 0.0);

// luz do cenário (Materiais.definir_luz): direção PARA o sol e as cores
// já em luz linear (cor x força)
uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec3 luz_cor = vec3(1.05, 0.935, 0.745);
uniform vec3 ambiente = vec3(0.212, 0.278, 0.439);

varying vec3 cor;
varying vec3 luz_lin;
varying vec2 uv_rosto;
varying float mascara_rosto;

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
	float ndl = dot(n, normalize(luz_dir));
	float t = smoothstep(-faixa, faixa, ndl - 0.02);
	vec3 l = luz_cor * max(t, luz_minima) + ambiente;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float rim = pow(1.0 - clamp(dot(nv, v), 0.0, 1.0), 3.0);
	vec3 soma = s2l(s2l(cor_borda.rgb)) * borda * rim * base + s2l(s2l(emissao.rgb)) + vec3(flash) * base;
	float brilho = 1.0 - clamp(abs(COLOR.a - 0.5) * 5.0, 0.0, 1.0);
	soma += base * brilho * brilho_luz;
	if (especular > 0.0) {
		vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
		float s = smoothstep(tamanho_especular, tamanho_especular + 0.02, dot(nv, normalize(v + lv)));
		soma += luz_cor * s * especular;
	}
	cor = tela(base * l + soma);
	luz_lin = l;
	uv_rosto = (VERTEX.xy - rosto_centro) / rosto_tamanho + 0.5;
	uv_rosto.y = 1.0 - uv_rosto.y;
	mascara_rosto = smoothstep(0.75, 0.95, COLOR.a) * smoothstep(0.05, 0.3, NORMAL.z);
}

void fragment() {
	vec3 c = cor;
	if (usa_rosto && mascara_rosto > 0.01) {
		vec2 uv = uv_rosto;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			vec4 f = texture(rosto, (clamp(uv, 0.004, 0.996) + rosto_celula) / rosto_grade);
			c = mix(c, tela_rapida(f.rgb * f.rgb * luz_lin), f.a * mascara_rosto);
		}
	}
	ALBEDO = c;
}
