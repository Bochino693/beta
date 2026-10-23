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


// COR VIVA: realça mais as cores menos saturadas (céu, madeira, chão) e
// quase não mexe nas que já são fortes, com um pouco mais de contraste.
// Era uma passada a mais na tela inteira (tela3d.shader); aqui sai de
// graça, na mesma conta que entrega a cor (as mesmas contas de lá).
vec3 viva(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(lum), c, 1.08 + 0.32 * (1.0 - sat));
	return clamp(c * 1.07 - 0.035, 0.0, 1.0);
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
	vec3 cam = CAMERA_MATRIX[3].xyz;
	vec3 f = normalize(direcao);
	vec3 centro = cam + f * distancia;
	// de frente para a câmera e EM PÉ no mundo: o "para cima" é o do céu,
	// não o da câmera — com a TV de pé ligada deitada a câmera gira 90° e
	// o sol (com os eixos dela) saía deitado
	vec3 dir = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
	vec3 cima = cross(dir, f);
	vec3 p = centro + (dir * VERTEX.x + cima * VERTEX.y) * tamanho;
	POSITION = PROJECTION_MATRIX * (INV_CAMERA_MATRIX * vec4(p, 1.0));
	float a = mod(TIME * giro, 1.0) * 6.2831853;
	// o QuadMesh do Godot 3 tem o V de baixo para cima: sem virar, o rosto
	// aparecia de ponta-cabeça (a boca em cima dos olhos)
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 q = uv - 0.5;
	uv_raios = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)) + 0.5;
	float pisca = step(piscar_cada - 0.16, mod(TIME, piscar_cada));
	uv_rosto = vec2((clamp(uv.x, 0.002, 0.998) + pisca) * 0.5, uv.y);
}

void fragment() {
	vec4 fundo = vec4(0.0);
	if (usa_raios > 0.5) {
		fundo = texture(raios, uv_raios);
	}
	vec4 r = texture(rosto, uv_rosto);
	float a_saida = r.a + fundo.a * (1.0 - r.a);
	vec3 cor = r.rgb * r.a + fundo.rgb * fundo.a * (1.0 - r.a);
	vec3 a = (cor / max(a_saida, 0.0001)) * tinta.rgb;
	ALBEDO = tela_g4(a);
	ALPHA = a_saida * tinta.a;
}
