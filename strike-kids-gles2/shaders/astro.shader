shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// SOL E LUA COM ROSTINHO (Mundo._astro): um quadradinho sempre de frente
// para a câmera, colocado NA DIREÇÃO do sol do céu e sempre à mesma
// distância da câmera — como o céu, fica "no infinito". Os raios giram
// devagar e o rosto pisca de vez em quando, pelo relógio (TIME). Edição
// OpenGL ES 2.0: o giro e o piscar são calculados por vértice.

uniform sampler2D rosto : hint_albedo;  // 2 quadros: olhos abertos | piscando
uniform sampler2D raios : hint_albedo;
uniform float usa_raios = 1.0;
uniform float giro = 0.02;          // voltas por segundo
uniform float piscar_cada = 4.5;    // segundos entre uma piscada e outra
uniform vec4 tinta : hint_color = vec4(1.0);
uniform vec3 direcao = vec3(0.146, 0.358, -0.922);
uniform float distancia = 140.0;    // da câmera até ele (m)
uniform float tamanho = 17.8;       // lado do quadrado a essa distância (m)

varying vec2 uv_raios;
varying vec2 uv_rosto;

void vertex() {
	vec3 cam = CAMERA_MATRIX[3].xyz;
	vec3 centro = cam + normalize(direcao) * distancia;
	vec3 p = centro + (CAMERA_MATRIX[0].xyz * VERTEX.x + CAMERA_MATRIX[1].xyz * VERTEX.y) * tamanho;
	POSITION = PROJECTION_MATRIX * (INV_CAMERA_MATRIX * vec4(p, 1.0));
	float a = mod(TIME * giro, 1.0) * 6.2831853;
	vec2 q = UV - 0.5;
	uv_raios = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)) + 0.5;
	float pisca = step(piscar_cada - 0.16, mod(TIME, piscar_cada));
	uv_rosto = vec2((clamp(UV.x, 0.002, 0.998) + pisca) * 0.5, UV.y);
}

void fragment() {
	vec4 fundo = vec4(0.0);
	if (usa_raios > 0.5) {
		fundo = texture(raios, uv_raios);
	}
	vec4 r = texture(rosto, uv_rosto);
	float a_saida = r.a + fundo.a * (1.0 - r.a);
	vec3 cor = r.rgb * r.a + fundo.rgb * fundo.a * (1.0 - r.a);
	ALBEDO = (cor / max(a_saida, 0.0001)) * tinta.rgb;
	ALPHA = a_saida * tinta.a;
}
