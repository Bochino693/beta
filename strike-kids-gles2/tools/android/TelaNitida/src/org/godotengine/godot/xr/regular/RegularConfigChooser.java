package org.godotengine.godot.xr.regular;

import org.godotengine.godot.gl.GLSurfaceView;
import org.godotengine.godot.utils.GLUtils;

import android.content.Context;
import android.util.Log;

import java.io.File;

import javax.microedition.khronos.egl.EGL10;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.egl.EGLDisplay;

/**
 * STRIKE KIDS: o RegularConfigChooser do Godot 3.6.3 (o que escolhe o
 * formato da tela da TV) com ANTISSERRILHADO 4x DA PROPRIA TELA.
 *
 * O jogo desenha o 3D e a interface DIRETO na tela, numa passada so
 * (principal.gd, "modo direto"). Na Mali-400/450 o antisserrilhado da
 * propria tela e resolvido dentro da placa, ladrilho por ladrilho: bordas
 * lisas sem gastar memoria - o do Godot numa imagem 3D separada custava
 * uma copia da tela inteira a cada quadro.
 *
 * Igual ao original, mais: entre as telas com as mesmas cores, profundidade
 * e stencil pedidas, prefere a de 4 amostras; sem ela (ou com o arquivo
 * "sem_antisserrilhado" na pasta do jogo, user://), escolhe como o
 * original. O RegularFallbackConfigChooser (que herda daqui) continua
 * tentando 8888+24, 8888+16 e 565+16, nessa ordem.
 *
 * Feito por tools/android/TelaNitida/construir.sh (que poe esta classe no
 * classes.dex do modelo Android, no lugar da original).
 */
public class RegularConfigChooser implements GLSurfaceView.EGLConfigChooser {
	private static final String TAG = RegularConfigChooser.class.getSimpleName();

	private static final int EGL_SAMPLES = 0x3031;
	private static final int EGL_SAMPLE_BUFFERS = 0x3032;
	private static final int AMOSTRAS = 4;

	private int[] mValue = new int[1];

	private static int EGL_OPENGL_ES2_BIT = 4;
	private static int[] s_configAttribs2 = {
		EGL10.EGL_RED_SIZE, 4,
		EGL10.EGL_GREEN_SIZE, 4,
		EGL10.EGL_BLUE_SIZE, 4,
		EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
		EGL10.EGL_NONE
	};
	private static int[] s_configAttribs3 = {
		EGL10.EGL_RED_SIZE, 4,
		EGL10.EGL_GREEN_SIZE, 4,
		EGL10.EGL_BLUE_SIZE, 4,
		EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
		EGL10.EGL_NONE
	};

	protected int mRedSize;
	protected int mGreenSize;
	protected int mBlueSize;
	protected int mAlphaSize;
	protected int mDepthSize;
	protected int mStencilSize;

	public RegularConfigChooser(int r, int g, int b, int a, int depth, int stencil) {
		mRedSize = r;
		mGreenSize = g;
		mBlueSize = b;
		mAlphaSize = a;
		mDepthSize = depth;
		mStencilSize = stencil;
	}

	public EGLConfig chooseConfig(EGL10 egl, EGLDisplay display) {
		int[] num_config = new int[1];
		egl.eglChooseConfig(display, GLUtils.use_gl3 ? s_configAttribs3 : s_configAttribs2, null, 0, num_config);
		int numConfigs = num_config[0];
		if (numConfigs <= 0) {
			throw new IllegalArgumentException("No configs match configSpec");
		}
		EGLConfig[] configs = new EGLConfig[numConfigs];
		egl.eglChooseConfig(display, GLUtils.use_gl3 ? s_configAttribs3 : s_configAttribs2, configs, numConfigs, num_config);
		return chooseConfig(egl, display, configs);
	}

	public EGLConfig chooseConfig(EGL10 egl, EGLDisplay display, EGLConfig[] configs) {
		if (comAntisserrilhado()) {
			EGLConfig c = escolher(egl, display, configs, AMOSTRAS);
			if (c != null) {
				Log.i(TAG, "Strike Kids: tela com antisserrilhado " + AMOSTRAS + "x da placa");
				return c;
			}
		}
		return escolher(egl, display, configs, 0);
	}

	/** amostras 0: a primeira que serve, como no original. */
	private EGLConfig escolher(EGL10 egl, EGLDisplay display, EGLConfig[] configs, int amostras) {
		for (EGLConfig config : configs) {
			int d = findConfigAttrib(egl, display, config, EGL10.EGL_DEPTH_SIZE, 0);
			int s = findConfigAttrib(egl, display, config, EGL10.EGL_STENCIL_SIZE, 0);
			// We need at least mDepthSize and mStencilSize bits
			if (d < mDepthSize || s < mStencilSize) {
				continue;
			}
			// We want an *exact* match for red/green/blue/alpha
			int r = findConfigAttrib(egl, display, config, EGL10.EGL_RED_SIZE, 0);
			int g = findConfigAttrib(egl, display, config, EGL10.EGL_GREEN_SIZE, 0);
			int b = findConfigAttrib(egl, display, config, EGL10.EGL_BLUE_SIZE, 0);
			int a = findConfigAttrib(egl, display, config, EGL10.EGL_ALPHA_SIZE, 0);
			if (r != mRedSize || g != mGreenSize || b != mBlueSize || a != mAlphaSize) {
				continue;
			}
			if (amostras > 0 && (findConfigAttrib(egl, display, config, EGL_SAMPLE_BUFFERS, 0) < 1 ||
										findConfigAttrib(egl, display, config, EGL_SAMPLES, 0) != amostras)) {
				continue;
			}
			return config;
		}
		return null;
	}

	/** O operador pode desligar (menu do operador): arquivo user://sem_antisserrilhado. */
	private static boolean comAntisserrilhado() {
		try {
			Object app = Class.forName("android.app.ActivityThread").getMethod("currentApplication").invoke(null);
			if (app instanceof Context) {
				return !new File(((Context)app).getFilesDir(), "sem_antisserrilhado").exists();
			}
		} catch (Throwable e) {
			Log.w(TAG, "Strike Kids: pasta do jogo nao encontrada (" + e + ")");
		}
		return true;
	}

	private int findConfigAttrib(EGL10 egl, EGLDisplay display, EGLConfig config, int attribute, int defaultValue) {
		if (egl.eglGetConfigAttrib(display, config, attribute, mValue)) {
			return mValue[0];
		}
		return defaultValue;
	}
}
