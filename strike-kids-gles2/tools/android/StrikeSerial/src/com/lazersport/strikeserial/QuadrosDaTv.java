package com.lazersport.strikeserial;

import android.app.Activity;
import android.opengl.EGL14;
import android.opengl.EGLDisplay;
import android.opengl.EGLExt;
import android.opengl.EGLSurface;
import android.view.Choreographer;

/**
 * 30 QUADROS TRAVADOS NA BATIDA DA TV (edição GLES2): cada quadro do jogo
 * fica na tela por exatamente 2 batidas da TV (60 Hz), como o "vSyncCount =
 * 2" do Unity e a biblioteca de ritmo de quadros do Android (Swappy). No
 * Android o eglSwapInterval(2) não vale (o sistema trava em 1): o certo é
 * dizer a cada quadro QUANDO ele deve aparecer (EGL_ANDROID_presentation_time),
 * sempre na grade das batidas da TV (Choreographer). A TV Box que não dá
 * conta de 60 na jogada mostrava 40-55 quadros desiguais (a imagem engasga
 * mesmo com a média boa); travado em 30, o movimento é uniforme.
 *
 * O próprio sistema segura o jogo no ritmo (a fila de imagens da tela
 * enche e o desenho espera): o Godot mede quadros de 1/30 s certinhos.
 */
final class QuadrosDaTv {

	private static volatile int intervalo = 1;       // batidas da TV por quadro: 1 = 60, 2 = 30
	private static volatile long periodo = 16666667L; // uma batida da TV (ns)
	private static volatile long ultimaBatida = 0;    // a última batida (ns, relógio do System.nanoTime)
	private static boolean ouvindo = false;           // (processo da interface)
	private static long ultimoAlvo = 0;              // (processo do desenho) a batida do quadro anterior

	private QuadrosDaTv() {
	}

	private static final Choreographer.FrameCallback BATIDA = new Choreographer.FrameCallback() {
		@Override
		public void doFrame(long t) {
			ultimaBatida = t;
			if (intervalo > 1) {
				Choreographer.getInstance().postFrameCallback(this);
			} else {
				ouvindo = false;
				ultimaBatida = 0;
			}
		}
	};

	static int intervalo() {
		return intervalo;
	}

	/** 1 = cada quadro numa batida (60 numa TV de 60 Hz), 2 = 30 travados. */
	static void definir(final Activity a, int n) {
		intervalo = Math.max(1, Math.min(3, n));
		if (intervalo <= 1) {
			return;
		}
		a.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				float hz = a.getWindowManager().getDefaultDisplay().getRefreshRate();
				if (hz > 20f && hz < 250f) {
					periodo = Math.round(1e9 / hz);
				}
				if (!ouvindo) {
					ouvindo = true;
					Choreographer.getInstance().postFrameCallback(BATIDA);
				}
			}
		});
	}

	/**
	 * No processo do desenho, depois do quadro desenhado e antes de ir para
	 * a tela (GodotPlugin.onGLDrawFrame): marca a batida em que ele aparece.
	 */
	static void antesDeTrocar() {
		int n = intervalo;
		long base = ultimaBatida;
		if (n <= 1 || base <= 0) {
			ultimoAlvo = 0;
			return;
		}
		long p = periodo;
		long agora = System.nanoTime();
		// a primeira batida que este quadro ainda alcança (uma batida inteira
		// para a placa terminar e a tela pegar), na grade das batidas
		long minimo = base + ((agora + p - base) / p + 1) * p;
		long alvo = minimo;
		if (ultimoAlvo > 0) {
			// `n` batidas depois do anterior (o sistema segura o jogo até lá);
			// atrasou, vai na primeira que dá
			long desejado = base + Math.round((double) (ultimoAlvo + n * p - base) / p) * p;
			if (desejado > minimo && desejado - agora < 4 * n * p) {
				alvo = desejado;
			}
		}
		ultimoAlvo = alvo;
		try {
			EGLDisplay d = EGL14.eglGetCurrentDisplay();
			EGLSurface s = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW);
			if (d != EGL14.EGL_NO_DISPLAY && s != EGL14.EGL_NO_SURFACE) {
				// um quarto de batida antes: a tela pega este, nunca o seguinte
				EGLExt.eglPresentationTimeANDROID(d, s, alvo - p / 4);
			}
		} catch (Throwable ignored) {
			intervalo = 1;   // aparelho sem o recurso: fica nos 60 de sempre
		}
	}
}
