shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// TERRENO LEVE (cenário LEVE, o padrão na TV Box): o MESMO desenho do
// terreno.gdshader — gramado listrado com florzinhas, chão de lua com
// crateras, areia com ondinhas e conchinhas, selva com manchas de terra e
// flores — mas muito mais barato por pixel:
//  * cada florzinha / concha / poeira cabe inteira na sua casinha da grade
//    (o centro fica entre 20% e 80% dela): basta olhar a casinha do pixel
//    (1 sorteio), não as 9 em volta;
//  * crateras: só as 4 casinhas mais perto (uma cratera alcança no máximo
//    1,6 m e a casinha tem 3,2 m: as outras nunca chegam no pixel);
//  * sorteio sem seno (o seno é caro na placa Mali);
//  * uma largura de pixel só para todas as bordas suaves;
//  * a luz (sol em duas faixas + ambiente) é feita por VÉRTICE, e as cores
//    já chegam lineares (Mundo.aplicar_tema).

uniform int modo = 0;
uniform vec3 lin_a = vec3(0.14, 0.6, 0.11);   // cores do chão, LINEARES
uniform vec3 lin_b = vec3(0.1, 0.48, 0.08);
uniform vec3 lin_c = vec3(1.0, 0.34, 0.64);   // detalhe 1 (flor, borda da cratera, concha...)
uniform vec3 lin_d = vec3(1.0, 0.83, 0.17);   // detalhe 2
uniform float faixa : hint_range(0.0, 0.5) = 0.25;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
// luz da cena: para onde está o sol (normalizado) e cor x força (lineares)
uniform vec3 sol_dir = vec3(0.35, 0.79, 0.5);
uniform vec3 sol_cor = vec3(1.0);
uniform vec3 ambiente = vec3(0.4);
// NEBLINA de profundidade por vértice (a do motor, por pixel, fica
// desligada no cenário leve): mesma conta exponencial e mesma cor
uniform vec3 neblina_cor = vec3(0.7, 0.8, 0.95);
uniform float neblina_densidade = 0.0;

varying vec3 pos_mundo;
varying vec3 luz;
varying float neblina;

// sorteio sem seno ("hash without sine", Dave Hoskins)
float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// bolinha da casinha do pixel: devolve cobertura (0..1) e um sorteio
vec2 ponto(vec2 p, float grade, float chance, float raio, float w) {
	vec2 cel = floor(p / grade);
	float r = h2(cel * 1.31);
	if (r <= chance) {
		return vec2(0.0);
	}
	vec2 centro = (cel + 0.2 + 0.6 * h22(cel)) * grade;
	float d = length(p - centro) - raio * (0.7 + 0.6 * fract(r * 13.0));
	return vec2(clamp(0.5 - d / w, 0.0, 1.0), fract(r * 7.0));
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = smoothstep(-faixa, faixa, dot(n, sol_dir) - 0.02);
	// o chão clareia um pouco no alto dos morros (como no terreno completo)
	float alt = clamp(pos_mundo.y / 4.0, 0.0, 1.0);
	luz = (ambiente + sol_cor * max(t, luz_minima)) * (1.0 + 0.23 * alt);
	neblina = 1.0 - exp(-neblina_densidade * length(CAMERA_POSITION_WORLD - pos_mundo));
}

void fragment() {
	vec2 p = pos_mundo.xz;
	// largura de um pixel no chão (bordas suaves, sem serrilhado)
	float w = (fwidth(p.x) + fwidth(p.y)) * 0.5 + 1e-5;
	vec3 c;
	if (modo == 0) {
		// listras do corte de grama + florzinhas
		float s = fract((p.y + p.x * 0.15) / 4.4) - 0.5;
		c = mix(lin_a, lin_b, clamp(0.5 - (abs(s) - 0.25) * 4.4 / (w * 1.15), 0.0, 1.0));
		vec2 f = ponto(p, 0.9, 0.9, 0.06, w);
		c = mix(c, mix(lin_c, lin_d, step(0.5, f.y)), f.x);
	} else if (modo == 1) {
		// lua: crateras (as 4 casinhas mais perto) + poeira brilhante
		c = lin_a;
		vec2 base = floor(p / 3.2 - 0.5);
		for (int j = 0; j <= 1; j++) {
			for (int i = 0; i <= 1; i++) {
				vec2 q = base + vec2(float(i), float(j));
				float r = h2(q * 2.7);
				if (r > 0.45) {
					vec2 centro = (q + 0.25 + 0.5 * h22(q)) * 3.2;
					float raio = 0.5 + 0.9 * fract(r * 9.0);
					float d = length(p - centro);
					c = mix(c, lin_b, clamp(0.5 - (d - raio) / w, 0.0, 1.0));
					c = mix(c, lin_c, clamp(0.5 - (abs(d - raio * 1.08) - raio * 0.08) / w, 0.0, 1.0));
				}
			}
		}
		vec2 f = ponto(p, 0.7, 0.93, 0.025, w);
		c = mix(c, lin_d, f.x);
	} else if (modo == 2) {
		// areia com ondinhas + conchinhas
		float onda = sin(p.x * 1.6 + sin(p.y * 0.35) * 2.0) * 0.5 + 0.5;
		c = mix(lin_a, lin_b, smoothstep(0.35, 0.65, onda));
		vec2 f = ponto(p, 1.1, 0.88, 0.045, w);
		c = mix(c, mix(lin_c, lin_d, step(0.5, f.y)), f.x);
	} else {
		// selva: verde fechado com manchas de terra + flores
		float m = sin(p.x * 0.45 + 1.3) * sin(p.y * 0.38) + 0.5 * sin(p.x * 1.1 - p.y * 0.9);
		float wm = w * 1.2;
		c = mix(lin_b, lin_a, clamp(0.5 + m / wm, 0.0, 1.0));
		c = mix(c, lin_d * vec3(0.45, 0.32, 0.17), clamp(0.5 - (1.05 - m) / wm, 0.0, 1.0));
		vec2 f = ponto(p, 1.0, 0.9, 0.055, w);
		c = mix(c, mix(lin_c, lin_d, step(0.5, f.y)), f.x);
	}
	ALBEDO = mix(c * luz, neblina_cor, neblina);
}
