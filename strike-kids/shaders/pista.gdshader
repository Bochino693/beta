shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// PISTA: madeira envernizada + marcações (setas, pontos, linha de falta,
// marcas dos pinos) + a marca Lazer & Sport impressa na madeira (sem
// fundo, por baixo do verniz, esticada no comprimento para ser lida de
// longe, como nas pistas de verdade) + luzes que correm pela borda.
// As coordenadas são do MUNDO: linha de falta em z = 0, pinos em z_pino1.

uniform sampler2D madeira : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meia_largura = 0.675;
uniform float repete = 3.6;
uniform float z_pino1 = -14.0;
uniform float bola_z = 100.0;
uniform float luz = 0.0;            // 0..1 (acende durante a jogada)
uniform float fase = 0.0;           // fase das luzes que correm (vem da CPU)
uniform vec3 cor_luz : source_color = vec3(0.35, 0.85, 1.0);
uniform vec3 cor_seta : source_color = vec3(0.45, 0.27, 0.16);   // marcas discretas, como numa pista de verdade
uniform float brilho_verniz = 0.55;
uniform sampler2D logo_marca : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool usa_marca = false;
uniform vec4 marca_ret = vec4(0.0, 5.6, 0.9, 0.95);   // centro x, distância da linha de falta, largura, comprimento
uniform float marca_forca = 0.82;

varying vec3 pm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float tri(vec2 p, vec2 c, float w, float h) {
	// seta (triângulo apontando para os pinos, -z)
	vec2 q = p - c;
	float t = clamp((q.y + h) / h, 0.0, 1.0); // 0 na base, 1 na ponta
	return step(abs(q.x), w * (1.0 - t)) * step(-h, q.y) * step(q.y, 0.0);
}

void fragment() {
	vec2 uv = vec2(pm.x / (meia_largura * 2.0) + 0.5, -pm.z / repete);
	vec3 c = texture(madeira, uv).rgb;
	float d = -pm.z;       // distância da linha de falta
	float ax = abs(pm.x);
	// linha de falta
	c = mix(c, vec3(0.88, 0.1, 0.12), step(abs(d - 0.02), 0.025));
	// pontos-guia (2 m)
	for (int i = -2; i <= 2; i++) {
		float x = float(i) * 0.17;
		float dd = length(vec2(pm.x - x, d + z_pino1 * 0.15));
		c = mix(c, cor_seta, 1.0 - smoothstep(0.018, 0.024, dd));
	}
	// setas (a 1/3 da pista) em forma de V
	float s = 0.0;
	for (int i = -3; i <= 3; i++) {
		float x = float(i) * 0.17;
		float zc = -z_pino1 * 0.33 + abs(float(i)) * 0.32;
		s += tri(vec2(pm.x, -d), vec2(x, -zc), 0.035, 0.22);
	}
	c = mix(c, cor_seta, clamp(s, 0.0, 1.0));
	// marcas dos pinos (bolinhas claras no fim da pista)
	vec2 r = vec2(pm.x, d + z_pino1);
	float marca = 0.0;
	for (int lin = 0; lin < 4; lin++) {
		for (int k = 0; k <= lin; k++) {
			vec2 p = vec2((float(k) - float(lin) * 0.5) * 0.38, -float(lin) * 0.329);
			marca += 1.0 - smoothstep(0.075, 0.085, length(r - vec2(p.x, -p.y)));
		}
	}
	c = mix(c, c * 1.18 + vec3(0.04), clamp(marca, 0.0, 1.0));
	// marca Lazer & Sport impressa (o topo do desenho fica do lado dos pinos)
	if (usa_marca) {
		vec2 um = vec2((pm.x - marca_ret.x) / marca_ret.z + 0.5, 0.5 - (d - marca_ret.y) / marca_ret.w);
		if (um.x > 0.0 && um.x < 1.0 && um.y > 0.0 && um.y < 1.0) {
			vec4 m = texture(logo_marca, um);
			vec3 impressa = mix(m.rgb, m.rgb * c * 1.25, 0.22);   // tinta sobre a madeira
			c = mix(c, impressa, m.a * marca_forca);
		}
	}
	// área dos pinos um pouco mais clara
	c *= mix(1.0, 1.08, smoothstep(-z_pino1 - 0.7, -z_pino1 - 0.4, d));
	ALBEDO = c;
	ROUGHNESS = 0.18;
	SPECULAR = brilho_verniz;
	// luzes nas bordas: correm na direção dos pinos e um brilho segue a bola
	float borda = smoothstep(meia_largura - 0.07, meia_largura - 0.01, ax);
	float corre = step(0.55, fract(d * 1.4 - fase));
	float onda = exp(-abs(d - bola_z) * 1.6);
	vec3 e = cor_luz * borda * (corre * 0.55 + onda * 1.6) * luz;
	// faixa de luz embaixo da bola
	e += cor_luz * onda * luz * 0.18 * (1.0 - borda);
	EMISSION = e;
}
