shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// PISTA DO STRIKE KIDS — edição OpenGL ES 2.0 (Mali-400/450).
// A decoração que não mexe (madeira envernizada, linha de falta, pontos,
// trilha de estrelas, setas arco-íris, marcas e holofote dos pinos) vem
// pronta na textura `pista_pronta` (tools: assar_pista.py, as mesmas contas
// do pista.gdshader do Godot 4). Aqui só o que mexe: as estrelas piscando
// em sequência até os pinos, o verniz refletindo o céu e o portal, o
// brilho do sol, o NEON das bordas com as luzes correndo e o brilho que
// acompanha a bola. Contas em luz linear; a saída volta para a tela (sqrt).
// Coordenadas do MUNDO: linha de falta em z = 0, pinos em z_pino1.

uniform sampler2D pista_pronta;      // RGB = sqrt(cor / 1.6), A = estrelas
uniform float meia_largura = 0.675;
uniform float z_pino1 = -10.5;
uniform float z_inicio = 0.1;        // a textura vai de z_inicio ...
uniform float z_fim = -11.95;        // ... até z_fim
uniform float bola_z = 100.0;
uniform float luz = 0.0;            // 0..1 (acende forte durante a jogada)
uniform float fase = 0.0;           // fase das luzes que correm (vem da CPU)
uniform float fase_lenta = 0.0;     // fase da onda das estrelas (0..1, vem da CPU)
uniform float pulso = 0.0;          // 0..1 (pulsa devagar, vem da CPU)
uniform vec4 cor_luz : hint_color = vec4(0.35, 0.85, 1.0, 1.0);      // neon das bordas
uniform vec4 cor_reflexo_a : hint_color = vec4(1.0, 0.76, 0.1, 1.0); // o portal no verniz
uniform vec4 cor_reflexo_b : hint_color = vec4(0.91, 0.22, 0.31, 1.0);
uniform vec3 luz_cena = vec3(1.2, 1.2, 1.22);   // linear (o Mundo calcula)
uniform vec4 cor_ceu : hint_color = vec4(0.85, 0.93, 1.0, 1.0);
uniform vec3 dir_sol = vec3(0.35, 0.79, 0.5);
uniform float verniz = 0.32;

// a coordenada da textura vai direto do vértice para a leitura (na Mali-400
// assim ela não perde precisão); `xd` = (x, distância da linha de falta)
varying vec2 uv_p;
varying vec2 xd;
varying vec3 olhar;

void vertex() {
	vec3 pm = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	uv_p = vec2(pm.x / (meia_largura * 2.0) + 0.5, (pm.z - z_inicio) / (z_fim - z_inicio));
	xd = vec2(pm.x, -pm.z);
	olhar = CAMERA_MATRIX[3].xyz - pm;
}

void fragment() {
	vec4 t = texture(pista_pronta, uv_p);
	vec3 c = t.rgb * t.rgb * 1.6;
	float d = xd.y;
	float ax = abs(xd.x);
	float dp = -z_pino1;
	float chamado = 1.0 - luz;   // esperando a bola: a pista "chama" a jogada

	// TRILHA DE ESTRELAS: acendem em sequência até os pinos (a textura tem
	// as estrelas apagadas e a máscara de cada uma)
	if (t.a > 0.004) {
		float k = clamp(floor((d - 2.3) / 1.35 + 0.5), 0.0, 5.0);
		float onda = step(0.72, fract(fase_lenta - k * 0.14));
		float acesa = mix(0.35, 1.0, max(onda * chamado, luz * 0.7));
		c *= 1.0 + t.a * ((0.75 + 0.6 * acesa) / 0.96 - 1.0);
	}

	// luz da cena + verniz: reflete o céu quando se olha "deitado", o
	// portal colorido lá no fundo e um brilho do sol
	c *= luz_cena;
	vec3 v = normalize(olhar);
	float f1 = 1.0 - clamp(v.y, 0.0, 1.0);
	float f2 = f1 * f1;
	float fres = f2 * f2;
	c = mix(c, cor_ceu.rgb * cor_ceu.rgb, fres * verniz * 0.8);
	if (d > dp - 6.0) {
		float fundo = smoothstep(dp - 6.0, dp + 0.5, d);
		vec3 portal = mix(cor_reflexo_b.rgb, cor_reflexo_a.rgb, 0.5 + 0.5 * sin(xd.x * 9.0));
		c += portal * portal * fres * fundo * 0.28;
	}
	vec3 refl = vec3(-v.x, v.y, -v.z);
	float b = max(dot(refl, dir_sol), 0.0);
	float b2 = b * b;
	float b4 = b2 * b2;
	float b16 = b4 * b4;
	b16 *= b16;
	c += vec3(1.0, 0.95, 0.85) * (b16 * b16 * b16 * verniz * 0.6);   // b^48

	// BORDAS DE NEON: sempre acesas na cor do cenário; esperando a bola,
	// luzes correm para os pinos (convite); na jogada, correm forte e um
	// brilho acompanha a bola
	vec3 neon = cor_luz.rgb * cor_luz.rgb;
	float borda = smoothstep(meia_largura - 0.085, meia_largura - 0.015, ax);
	float espalha = exp(-(meia_largura - ax) * 9.0) * 0.3;
	float fr = fract(d * 1.1 - fase);
	float corre = smoothstep(0.42, 0.58, fr) * smoothstep(0.98, 0.84, fr);
	float onda_bola = 0.0;
	if (luz > 0.001) {
		onda_bola = exp(-abs(d - bola_z) * 1.6);
	}
	float forca = 0.75 + 0.45 * corre * chamado + luz * (corre * 0.6 + onda_bola * 1.4);
	vec3 e = neon * ((borda + espalha) * forca + onda_bola * luz * 0.18 * (1.0 - borda));
	ALBEDO = sqrt(c + e);
}
