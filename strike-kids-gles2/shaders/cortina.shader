shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// CORTINA DA CAÇAPA DAS BOLAS: as 7 tiras de borracha numa malha só (um
// desenho), com o desenho do cenário (texturas/cortina_bola.png, uma faixa
// por cenário) cortado entre elas. Cada tira gira presa em cima, para
// DENTRO do túnel, pelo ângulo dela (a0..a6, o Mundo manda quando a bola
// passa). UV2.x = qual tira; o vértice vem com a dobradiça em y = 0.

uniform sampler2D desenho;
uniform float linha = 0.0;          // o cenário: a faixa da imagem (0..3)
uniform float brilho = 1.0;
uniform float a0 = 0.0;
uniform float a1 = 0.0;
uniform float a2 = 0.0;
uniform float a3 = 0.0;
uniform float a4 = 0.0;
uniform float a5 = 0.0;
uniform float a6 = 0.0;

varying vec2 uv_d;
varying float u_tira;
varying float uv_y;

void vertex() {
	float i = UV2.x;
	float a = a0;
	if (i > 5.5) {
		a = a6;
	} else if (i > 4.5) {
		a = a5;
	} else if (i > 3.5) {
		a = a4;
	} else if (i > 2.5) {
		a = a3;
	} else if (i > 1.5) {
		a = a2;
	} else if (i > 0.5) {
		a = a1;
	}
	// gira em volta do eixo x (a dobradiça): a ponta de baixo vai para -z
	VERTEX = vec3(VERTEX.x, VERTEX.y * cos(a), VERTEX.y * sin(a));
	uv_d = vec2((i + UV.x) / 7.0, (linha + UV.y) / 4.0);
	u_tira = UV.x;
	uv_y = UV.y;
}

void fragment() {
	vec3 c = texture(desenho, uv_d).rgb;
	// a borda de cada tira só um pouco mais escura (lê-se a borracha).
	// (Antes o "verso" ficava a 30%: na TV Box e na imagem do jogo a GPU
	// via a FRENTE das tiras como verso e o desenho do cenário saía quase
	// preto - a caçapa escura. Da vista do jogo só a frente aparece: as
	// tiras abrem para DENTRO do túnel.)
	float borda = smoothstep(0.0, 0.05, min(u_tira, 1.0 - u_tira));
	c *= (0.8 + 0.2 * borda) * brilho;
	// um brilho que desce da luz em cima da boca (a tira acesa, como na
	// abertura) e some até a ponta de baixo
	c += c * 0.18 * (1.0 - uv_y);
	ALBEDO = c;
}
