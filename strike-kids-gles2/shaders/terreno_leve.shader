shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// CHÃO DOS CENÁRIOS — edição OpenGL ES 2.0: a luz, a neblina e o desenho
// grande do chão (listras do gramado, ondinhas da areia, manchas da selva)
// são feitos por vértice ou com uma conta só por pixel. Os detalhes miúdos
// (florzinhas, crateras e poeira da lua, conchinhas) vêm de uma textura que
// se repete (`detalhe`, feita por tools/assar_chao.py com as mesmas contas
// do Godot 4): na Mali-400 a conta de pixel é em meia precisão e o sorteio
// por pixel piscaria. Mesmos nomes de parâmetros do Godot 4.

uniform int modo = 0;
uniform vec3 lin_a = vec3(0.14, 0.6, 0.11);   // cores do chão
uniform vec3 lin_b = vec3(0.1, 0.48, 0.08);
uniform vec3 lin_c = vec3(1.0, 0.34, 0.64);   // detalhe 1
uniform vec3 lin_d = vec3(1.0, 0.83, 0.17);   // detalhe 2
uniform vec3 terra = vec3(0.45, 0.32, 0.17);
uniform float faixa : hint_range(0.0, 0.5) = 0.25;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sol_dir = vec3(0.35, 0.79, 0.5);
uniform vec3 sol_cor = vec3(1.0);
uniform vec3 ambiente = vec3(0.4);
uniform vec3 neblina_cor = vec3(0.7, 0.8, 0.95);
uniform float neblina_densidade = 0.0;
// R = cor B do chão (fundo da cratera), G = detalhe 1, B = detalhe 2
uniform sampler2D detalhe : hint_black;
uniform float detalhe_tile = 25.0;   // metros de um ladrilho da textura

varying vec2 p;
varying vec2 uv_det;
varying vec3 luz;
varying float neblina;
varying float mancha;


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

// a cor CRUA, como o shader do Godot 4 a entregava, até a tela: lá ela
// ainda passava por sRGB -> linear, "filmic" (branco 1,6) e linear -> sRGB
// (medido no Godot 4). Aqui numa conta só, sem potência nem divisão
// (erro < 2%; satura em 1,25, como lá)
vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return viva(x * (1.2094 - x * (0.015 + 0.25 * x)));
}

void vertex() {
	vec3 pw = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	p = pw.xz;
	uv_det = p / detalhe_tile;
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = smoothstep(-faixa, faixa, dot(n, sol_dir) - 0.02);
	float alt = clamp(pw.y / 4.0, 0.0, 1.0);
	luz = (ambiente + sol_cor * max(t, luz_minima)) * (1.0 + 0.23 * alt);
	neblina = 1.0 - exp(-neblina_densidade * length(CAMERA_MATRIX[3].xyz - pw));
	// desenhos grandes e suaves: por vértice (o terreno tem malha fina)
	if (modo == 2) {
		mancha = sin(p.x * 1.6 + sin(p.y * 0.35) * 2.0) * 0.5 + 0.5;
	} else if (modo == 3) {
		mancha = sin(p.x * 0.45 + 1.3) * sin(p.y * 0.38) + 0.5 * sin(p.x * 1.1 - p.y * 0.9);
	} else {
		mancha = 0.0;
	}
}

void fragment() {
	vec3 c;
	if (modo == 0) {
		// listras do corte de grama
		float s = fract((p.y + p.x * 0.15) / 4.4) - 0.5;
		c = mix(lin_a, lin_b, clamp(0.5 - (abs(s) - 0.25) * 30.0, 0.0, 1.0));
	} else if (modo == 1) {
		// lua: cinza (as crateras vêm da textura)
		c = lin_a;
	} else if (modo == 2) {
		c = mix(lin_a, lin_b, smoothstep(0.35, 0.65, mancha));
	} else {
		c = mix(lin_b, lin_a, clamp(0.5 + mancha * 8.0, 0.0, 1.0));
		c = mix(c, lin_d * terra, clamp(0.5 - (1.05 - mancha) * 8.0, 0.0, 1.0));
	}
	// florzinhas, crateras, poeira, conchinhas (pesos de cada cor)
	vec3 w = texture(detalhe, uv_det).rgb;
	c += (lin_b - c) * w.r + (lin_c - c) * w.g + (lin_d - c) * w.b;
	// as mesmas contas do Godot 4 (cores lineares do Mundo)
	ALBEDO = tela_g4(mix(c * luz, neblina_cor, neblina));
}
