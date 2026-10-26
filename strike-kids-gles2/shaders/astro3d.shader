shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

// SOL, LUA E BALEIA EM 3D (Mundo._astro, 6.8): como o antigo astro.shader, o
// objeto fica NA DIREÇÃO do sol do céu e sempre à mesma distância da câmera
// — "no infinito", atrás de todo o cenário —, mas agora é um objeto de
// verdade: a malha (Mundo._malha_sol, _malha_lua, _malha_baleia) tem
// volume, o sombreado é de desenho (claro em cima, mais escuro embaixo e
// uma borda escura na volta, pela normal: sem passada de contorno) e ele
// mexe no vértice — balança a cabeça, respira, os raios do sol giram, o
// rabo da baleia bate. O rosto é pintado por cima (as artes de sempre: sol,
// lua; a baleia tem a dela) e pisca pelo relógio.
// Eixos do objeto: X para a direita da tela, Y para cima, Z para a câmera.
// (Sem descartar as faces de trás: objeto pequeno no céu, e as malhas
// feitas no código não precisam seguir a ordem de voltas do Godot.)

uniform sampler2D rosto : hint_albedo;   // 2 quadros: olhos abertos | piscando
uniform vec3 direcao = vec3(0.146, 0.358, -0.922);
uniform float distancia = 140.0;
uniform float tamanho = 17.8;
// o rosto: 0 = na frente (sol, lua: o disco da arte cobre a esfera),
// 1 = dos dois lados (baleia)
uniform float rosto_lado = 0.0;
uniform vec2 rosto_centro = vec2(0.0, 0.0);
uniform float rosto_escala = 1.6;
uniform float piscar_cada = 4.5;
// movimento (a baleia: giro_y e o deslocamento vêm do Mundo, a cada quadro)
uniform float giro_y = 0.0;
uniform vec2 deslocamento = vec2(0.0);
uniform float balanco = 0.1;        // inclina a cabeça de um lado para o outro (rad)
uniform float respira = 0.03;       // estica e encolhe
uniform float giro_raios = 0.03;    // voltas por segundo (vértices com UV2.x = 1)
uniform float rabo = 0.0;           // a batida do rabo (baleia)
uniform vec4 cor_borda : hint_color = vec4(0.8, 0.35, 0.05, 1.0);
uniform vec4 tinta : hint_color = vec4(1.0);
uniform vec4 nevoa : hint_color = vec4(0.5, 0.8, 1.0, 0.0);   // a: quanto (o mar)

varying vec3 p_local;
varying float luz;
varying float borda;
varying vec2 uv_rosto;

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	p_local = p;
	// raios do sol: giram em volta do Z
	if (UV2.x > 0.5) {
		float a = mod(TIME * giro_raios, 1.0) * 6.2831853;
		mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
		p.xy = r * p.xy;
		n.xy = r * n.xy;
	}
	// rabo da baleia: sobe e desce, mais na ponta (UV2.y: 0 no corpo, 1 na ponta)
	p.y += rabo * sin(TIME * 2.4) * UV2.y * UV2.y;
	// respira (estica para cima) e balança a cabeça
	p.y *= 1.0 + respira * sin(TIME * 1.7);
	p.x *= 1.0 - respira * 0.5 * sin(TIME * 1.7);
	float b = balanco * sin(TIME * 0.9);
	mat2 rb = mat2(vec2(cos(b), sin(b)), vec2(-sin(b), cos(b)));
	p.xy = rb * p.xy;
	n.xy = rb * n.xy;
	// a baleia vira para o lado que nada
	float cy = cos(giro_y);
	float sy = sin(giro_y);
	p.xz = vec2(cy * p.x + sy * p.z, -sy * p.x + cy * p.z);
	n.xz = vec2(cy * n.x + sy * n.z, -sy * n.x + cy * n.z);
	p.xy += deslocamento;
	// no céu, sempre de frente para a câmera e de pé no mundo
	vec3 cam = CAMERA_MATRIX[3].xyz;
	vec3 f = normalize(direcao);
	vec3 dir = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
	vec3 cima = cross(dir, f);
	vec3 mundo = cam + f * distancia + (dir * p.x + cima * p.y - f * p.z) * tamanho;
	POSITION = PROJECTION_MATRIX * (INV_CAMERA_MATRIX * vec4(mundo, 1.0));
	// sombreado de desenho: luz de cima/esquerda, borda pela normal de frente
	vec3 nn = normalize(n);
	luz = 0.78 + 0.32 * dot(nn, normalize(vec3(-0.45, 0.65, 0.6)));
	borda = nn.z;
	float pisca = step(piscar_cada - 0.16, mod(TIME, piscar_cada));
	vec2 q = (p_local.xy - rosto_centro) / rosto_escala;
	uv_rosto = vec2((clamp(q.x + 0.5, 0.002, 0.998) + pisca) * 0.5, 0.5 - q.y);
}

void fragment() {
	vec3 c = COLOR.rgb * luz;
	// o rosto (só na frente; na baleia, dos dois lados)
	float frente = rosto_lado > 0.5 ? step(0.05, abs(p_local.z)) : step(0.0, p_local.z);
	vec2 q = (p_local.xy - rosto_centro) / rosto_escala;
	float dentro = step(abs(q.x), 0.5) * step(abs(q.y), 0.5) * frente;
	vec4 r = texture(rosto, uv_rosto);
	c = mix(c, r.rgb, r.a * dentro);
	// a borda escura de desenho, na volta (lisa: pela normal interpolada)
	c = mix(cor_borda.rgb, c, smoothstep(0.12, 0.3, borda));
	c *= tinta.rgb;
	ALBEDO = mix(c, nevoa.rgb, nevoa.a);
}
