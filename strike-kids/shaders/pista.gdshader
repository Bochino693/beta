shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// PISTA: madeira envernizada + marcações (setas, pontos, linha de falta,
// marcas dos pinos) + luzes que correm pela borda acompanhando a bola.
// As coordenadas são do MUNDO: linha de falta em z = 0, pinos em z_pino1.
//
// LEVE (a pista cobre meia tela): nenhuma repetição por pixel — cada
// marcação acha a sua mais próxima com conta direta — e a luz é
// "desenhada" (cor da cena + verniz que reflete o céu + brilho do sol),
// sem o cálculo de luz completo do motor. Mesma cara, uma fração do custo.

uniform sampler2D madeira : source_color, filter_linear_mipmap, repeat_enable;
uniform float meia_largura = 0.675;
uniform float repete = 3.6;
uniform float z_pino1 = -14.0;
uniform float bola_z = 100.0;
uniform float luz = 0.0;            // 0..1 (acende durante a jogada)
uniform float fase = 0.0;           // fase das luzes que correm (vem da CPU)
uniform vec3 cor_luz : source_color = vec3(0.35, 0.85, 1.0);
uniform vec3 cor_seta : source_color = vec3(0.45, 0.27, 0.16);   // marcas discretas, como numa pista de verdade
uniform vec3 tom_madeira : source_color = vec3(1.0, 0.86, 0.66);  // mel: madeira quente, não branca
// luz da cena (o Mundo calcula: ambiente + sol no chão) e o que o verniz reflete
uniform vec3 luz_cena = vec3(1.2, 1.2, 1.22);
uniform vec3 cor_ceu : source_color = vec3(0.85, 0.93, 1.0);
uniform vec3 dir_sol = vec3(0.35, 0.79, 0.5);     // para onde está o sol (mundo)
uniform float verniz = 0.32;

varying vec3 pm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// seta (triângulo apontando para os pinos, -z): 1 dentro, 0 fora
float tri(vec2 q, float w, float h) {
	float t = clamp((q.y + h) / h, 0.0, 1.0); // 0 na base, 1 na ponta
	return step(abs(q.x), w * (1.0 - t)) * step(-h, q.y) * step(q.y, 0.0);
}

void fragment() {
	vec2 uv = vec2(pm.x / (meia_largura * 2.0) + 0.5, -pm.z / repete);
	vec3 c = texture(madeira, uv).rgb * tom_madeira;
	float d = -pm.z;       // distância da linha de falta
	float ax = abs(pm.x);
	// linha de falta
	c = mix(c, vec3(0.88, 0.1, 0.12), step(abs(d - 0.02), 0.025));
	// pontos-guia: 5 pontinhos a cada 17 cm (o mais perto)
	float ip = clamp(round(pm.x / 0.17), -2.0, 2.0);
	float dd = length(vec2(pm.x - ip * 0.17, d + z_pino1 * 0.15));
	c = mix(c, cor_seta, 1.0 - smoothstep(0.018, 0.024, dd));
	// setas em V (a 1/3 da pista): a seta da coluna mais perto
	float is = clamp(round(pm.x / 0.17), -3.0, 3.0);
	float zc = -z_pino1 * 0.33 + abs(is) * 0.32;
	c = mix(c, cor_seta, tri(vec2(pm.x - is * 0.17, zc - d), 0.035, 0.22));
	// marcas dos pinos: a fileira e o pino mais perto (triângulo de 10)
	vec2 r = vec2(pm.x, d + z_pino1);
	float lin = clamp(round(r.y / 0.329), 0.0, 3.0);
	float k = clamp(round(r.x / 0.38 + lin * 0.5), 0.0, lin);
	vec2 mp = vec2((k - lin * 0.5) * 0.38, lin * 0.329);
	float marca = 1.0 - smoothstep(0.075, 0.085, length(r - mp));
	c = mix(c, c * 1.18 + vec3(0.04), marca);
	// área dos pinos um pouco mais clara
	c *= mix(1.0, 1.08, smoothstep(-z_pino1 - 0.7, -z_pino1 - 0.4, d));
	// luz da cena + verniz: reflete o céu quando se olha "deitado" e um
	// brilho do sol na direção do reflexo
	c *= luz_cena;
	vec3 v = normalize(CAMERA_POSITION_WORLD - pm);
	float fres = pow(1.0 - clamp(v.y, 0.0, 1.0), 4.0);
	c = mix(c, cor_ceu, fres * verniz);
	vec3 refl = vec3(-v.x, v.y, -v.z);
	float brilho = pow(max(dot(refl, normalize(dir_sol)), 0.0), 48.0);
	c += vec3(1.0, 0.95, 0.85) * brilho * verniz * 0.6;
	// luzes nas bordas: correm na direção dos pinos e um brilho segue a bola
	float borda = smoothstep(meia_largura - 0.07, meia_largura - 0.01, ax);
	float corre = step(0.55, fract(d * 1.4 - fase));
	float onda = exp(-abs(d - bola_z) * 1.6);
	vec3 e = cor_luz * borda * (corre * 0.55 + onda * 1.6) * luz;
	e += cor_luz * onda * luz * 0.18 * (1.0 - borda);
	ALBEDO = c + e;
}
