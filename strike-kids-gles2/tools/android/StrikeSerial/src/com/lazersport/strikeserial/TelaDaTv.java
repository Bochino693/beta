package com.lazersport.strikeserial;

import android.app.Activity;
import android.content.Context;
import android.graphics.Matrix;
import android.graphics.Point;
import android.util.Log;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.SurfaceView;
import android.view.View;

/**
 * A RESOLUÇÃO DA IMAGEM DO JOGO NA TV BOX (edição GLES2): o mesmo que o
 * Screen.SetResolution do Unity faz no Android. O jogo desenha numa imagem
 * menor que a tela (ex.: 1280x720 numa TV 1920x1080) e quem estica até a
 * tela inteira é o próprio Android, no hardware de vídeo da TV Box (o
 * compositor) - de graça para a placa de vídeo, sem nenhuma passada a mais
 * no jogo. Na Mali-400/450, 720 linhas em vez de 1080 são menos da metade
 * dos pixels a pintar em cada quadro.
 *
 * O tamanho fica guardado (SharedPreferences "strike_tela"): ao abrir o
 * jogo ele já vale antes de a tela do Godot nascer (StrikeSerial.onMainCreate),
 * sem trocar a imagem com o jogo rodando. Toque e mouse (controle com
 * ponteiro) chegam na escala da tela inteira: são trazidos para a da imagem.
 */
final class TelaDaTv {

	private static final String TAG = "StrikeSerial";
	private static final String PREFS = "strike_tela";
	private static final String CHAVE = "altura";

	private static int alturaPedida = 0;
	private static int largura = 0;      // a imagem de agora (0 = a da própria tela)
	private static int altura = 0;
	private static boolean ouvindo = false;

	private TelaDaTv() {
	}

	static int lerAltura(Context c) {
		return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(CHAVE, 0);
	}

	static void guardarAltura(Context c, int alt) {
		c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt(CHAVE, alt).apply();
	}

	/** O tamanho da tela inteira (o da vista do jogo; antes dela existir, o do aparelho). */
	static Point tamanhoDaTela(Activity a, View v) {
		if (v != null && v.getWidth() > 0 && v.getHeight() > 0) {
			return new Point(v.getWidth(), v.getHeight());
		}
		Point p = new Point();
		a.getWindowManager().getDefaultDisplay().getRealSize(p);
		return p;
	}

	/** "1920x1080|1280x720": a tela e a imagem do jogo (iguais = a da própria tela). */
	static String descrever(Activity a, View v) {
		Point t = tamanhoDaTela(a, v);
		int w = largura > 0 ? largura : t.x;
		int h = largura > 0 ? altura : t.y;
		return t.x + "x" + t.y + "|" + w + "x" + h;
	}

	/**
	 * A imagem com `alt` pixels no lado menor (0, ou maior ou igual ao da
	 * tela = a resolução da própria tela). Chamar no processo da interface.
	 */
	static void aplicar(final Activity a, final SurfaceView v, int alt) {
		alturaPedida = alt;
		if (!ouvindo) {
			ouvindo = true;
			// a vista ganha o tamanho de verdade depois (barras do sistema,
			// tela girada): a imagem acompanha, sempre na mesma proporção
			v.addOnLayoutChangeListener(new View.OnLayoutChangeListener() {
				@Override
				public void onLayoutChange(View vista, int l, int t, int r, int b, int ol, int ot, int or, int ob) {
					if (r - l != or - ol || b - t != ob - ot) {
						medir(a, v);
					}
				}
			});
			v.setOnTouchListener(new View.OnTouchListener() {
				@Override
				public boolean onTouch(View vista, MotionEvent ev) {
					return reescalar(vista, ev, false);
				}
			});
			v.setOnGenericMotionListener(new View.OnGenericMotionListener() {
				@Override
				public boolean onGenericMotion(View vista, MotionEvent ev) {
					return reescalar(vista, ev, true);
				}
			});
		}
		medir(a, v);
	}

	private static void medir(Activity a, SurfaceView v) {
		Point t = tamanhoDaTela(a, v);
		int menor = Math.min(t.x, t.y);
		int w = 0;
		int h = 0;
		if (alturaPedida > 0 && alturaPedida < menor) {
			float k = (float) alturaPedida / (float) menor;
			// pares: alguns compositores esticam melhor (e o MSAA não reclama)
			w = Math.round(t.x * k / 2f) * 2;
			h = Math.round(t.y * k / 2f) * 2;
		}
		if (w == largura && h == altura) {
			return;
		}
		largura = w;
		altura = h;
		if (w > 0) {
			v.getHolder().setFixedSize(w, h);
		} else {
			v.getHolder().setSizeFromLayout();
		}
		try {
			Log.i(TAG, "tela " + t.x + "x" + t.y + ", imagem do jogo " + (w > 0 ? w + "x" + h : "da tela"));
		} catch (Throwable ignored) {
		}
	}

	/**
	 * Toque/mouse da escala da tela para a da imagem (a cópia vai para o
	 * Godot). Só o que aponta: o direcional da placa e os controles chegam
	 * aqui também (eixos de joystick), e esses passam sem mexer.
	 */
	private static boolean reescalar(View vista, MotionEvent ev, boolean generico) {
		if (largura <= 0 || vista.getWidth() <= 0 || vista.getHeight() <= 0
				|| (ev.getSource() & InputDevice.SOURCE_CLASS_POINTER) == 0) {
			return false;
		}
		Matrix m = new Matrix();
		m.setScale((float) largura / vista.getWidth(), (float) altura / vista.getHeight());
		MotionEvent c = MotionEvent.obtain(ev);
		c.transform(m);
		try {
			if (generico) {
				vista.onGenericMotionEvent(c);
			} else {
				vista.onTouchEvent(c);
			}
		} finally {
			c.recycle();
		}
		return true;
	}
}
