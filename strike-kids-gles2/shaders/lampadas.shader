shader_type spatial;
render_mode unshaded, cull_back;

// LÂMPADAS DO LETREIRO (MultiMesh). Cada lâmpada tem a cor da instância e
// um número em INSTANCE_CUSTOM.r; o padrão do pisca vem de `fase`
// (calculada na CPU). Tudo por vértice (a lâmpada é pequena).

uniform float fase = 0.0;
uniform int modo = 0;          // 0 corrida, 1 todas piscando, 2 alternado
uniform float intensidade = 1.6;

varying vec3 cor;


// cor como no Godot 4: s2l = sRGB -> linear; tela = "filmic" (branco 1,6)
// + sRGB (por vértice, exata)
vec3 s2l(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float s2l1(float c) {
	return c < 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

vec3 tela(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 f = clamp(((x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.6) + 0.06) - 0.033333) / 0.68495, 0.0, 1.0);
	return mix(f * 12.92, 1.055 * pow(f, vec3(0.416667)) - 0.055, step(vec3(0.0031308), f));
}

void vertex() {
	float n = INSTANCE_CUSTOM.r;
	float on;
	if (modo == 0) {
		on = 0.25 + 0.75 * step(0.6, fract(n * 0.25 - fase));
	} else if (modo == 1) {
		on = 0.3 + 0.7 * step(0.5, fract(fase * 2.0));
	} else {
		on = 0.25 + 0.75 * step(0.5, fract(n * 0.5 + fase * 2.0));
	}
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rim = clamp(dot(nv, normalize(-pv)), 0.0, 1.0);
	cor = tela(s2l(s2l(COLOR.rgb)) * (0.35 + rim * 0.65) * on * intensidade + vec3(0.12) * rim);
}

void fragment() {
	ALBEDO = cor;
}
