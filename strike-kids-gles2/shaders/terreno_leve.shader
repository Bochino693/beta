shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// CHÃO DOS CENÁRIOS — edição OpenGL ES 2.0: a luz, a neblina e o desenho
// grande do chão (listras do gramado, crateras, ondinhas da areia, manchas
// da selva) são feitos por vértice ou com uma conta só por pixel; as
// florzinhas/conchinhas miúdas (sorteio por pixel) ficam de fora: na
// Mali-400 a conta de pixel é em meia precisão e o sorteio piscaria.
// Mesmos nomes de parâmetros do Godot 4 (terreno_leve.gdshader).

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

varying vec2 p;
varying vec3 luz;
varying float neblina;
varying float mancha;

void vertex() {
	vec3 pw = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	p = pw.xz;
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
		// lua: cinza com manchas largas
		float m = sin(p.x * 0.7) * sin(p.y * 0.6);
		c = mix(lin_a, lin_b, smoothstep(0.35, 0.55, m));
	} else if (modo == 2) {
		c = mix(lin_a, lin_b, smoothstep(0.35, 0.65, mancha));
	} else {
		c = mix(lin_b, lin_a, clamp(0.5 + mancha * 8.0, 0.0, 1.0));
		c = mix(c, lin_d * terra, clamp(0.5 - (1.05 - mancha) * 8.0, 0.0, 1.0));
	}
	// as cores chegam LINEARES do Mundo: sai convertida para a tela
	ALBEDO = sqrt(mix(c * luz, neblina_cor, neblina));
}
