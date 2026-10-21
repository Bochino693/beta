shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// CÉU de cada cenário — edição OpenGL ES 2.0 (o Godot 3 na OpenGL ES 2 não
// tem shader de céu): uma esfera desenhada no INFINITO (só a direção conta,
// a posição da câmera não), atrás de tudo. Degradê topo -> meio ->
// horizonte, brilho do sol e os extras: ESTRELAS + nebulosa (espaço, as
// estrelas vêm de uma textura, texturas/estrelas_ceu.png: na Mali-400 o
// sorteio por pixel piscaria) e
// RAIOS de luz vindos de cima (fundo do mar). Mesmos nomes do Godot 4.

uniform vec4 cor_topo : hint_color = vec4(0.20, 0.52, 1.0, 1.0);
uniform vec4 cor_meio : hint_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform vec4 cor_horizonte : hint_color = vec4(1.0, 0.86, 0.95, 1.0);
uniform vec4 cor_chao : hint_color = vec4(0.55, 0.82, 0.55, 1.0);
uniform vec3 dir_sol = vec3(0.35, 0.55, -0.75);
uniform vec4 cor_sol : hint_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform float forca_sol = 1.0;
uniform float estrelas = 0.0;
uniform vec4 cor_nebulosa : hint_color = vec4(0.9, 0.4, 1.0, 1.0);
uniform float raios = 0.0;
uniform sampler2D mapa_estrelas : hint_black;

varying vec3 dir;
varying float nebulosa;
varying float raio_luz;


// a cor CRUA, como o shader do Godot 4 a entregava, até a tela: lá ela
// ainda passava por sRGB -> linear, "filmic" (branco 1,6) e linear -> sRGB
// (medido no Godot 4, também no céu). Aqui numa conta só, sem potência nem
// divisão (erro < 2%; satura em 1,25, como lá)
vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return x * (1.2094 - x * (0.015 + 0.25 * x));
}

void vertex() {
	vec3 d = normalize(VERTEX);
	dir = d;
	// só a rotação da câmera: o céu fica no infinito, atrás de tudo
	vec3 v = (INV_CAMERA_MATRIX * vec4(d, 0.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(v, 1.0);
	POSITION.z = POSITION.w * 0.99999;
	// nebulosa e raios mudam devagar: por vértice
	float n = sin(d.x * 3.1 + sin(d.z * 2.3) * 1.7) * sin(d.y * 4.2 + d.z * 1.3) + 0.5 * sin(d.x * 7.0 - d.z * 5.0);
	nebulosa = smoothstep(0.35, 1.2, n) * 0.22 * estrelas;
	float a = max(0.0, sin(d.x * 21.0 + d.z * 9.0) * 0.5 + 0.5);
	float b = max(0.0, sin(d.x * 13.0 - d.z * 15.0 + 1.7) * 0.5 + 0.5);
	float a2 = a * a;
	float a8 = a2 * a2;
	a8 *= a8;
	float b2 = b * b;
	float b4 = b2 * b2;
	raio_luz = (a8 * a2 + b4 * b4 * b4 * b2 * 0.7) * smoothstep(0.05, 0.7, d.y) * 0.35 * raios;
}

void fragment() {
	vec3 d = normalize(dir);
	float y = d.y;
	// as mesmas contas do Godot 4 (cores cruas; a curva de tela no fim)
	vec3 c;
	vec3 h = cor_horizonte.rgb;
	if (y > 0.0) {
		c = mix(h, cor_meio.rgb, smoothstep(0.0, 0.18, y));
		c = mix(c, cor_topo.rgb, smoothstep(0.18, 0.75, y));
	} else {
		c = mix(h, cor_chao.rgb, smoothstep(0.0, -0.08, y));
	}
	if (estrelas > 0.0 && y > -0.02) {
		c += cor_nebulosa.rgb * nebulosa;
		// o mapa de estrelas segue a UV da própria esfera (SphereMesh): a
		// coordenada vai direto do vértice para a leitura (precisa)
		c += vec3(0.9, 0.92, 0.95) * texture(mapa_estrelas, UV).r * 2.2 * estrelas;
	}
	if (raios > 0.0 && y > 0.0) {
		c += vec3(0.75, 1.0, 0.95) * raio_luz;
	}
	float sol = max(dot(d, normalize(dir_sol)), 0.0);
	float s2 = sol * sol;
	float s4 = s2 * s2;
	float s8 = s4 * s4;
	c += cor_sol.rgb * (s8 * s4 * 0.25) * forca_sol;
	ALBEDO = tela_g4(c);
}
