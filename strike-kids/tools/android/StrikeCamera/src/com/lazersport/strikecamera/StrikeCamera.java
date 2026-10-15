package com.lazersport.strikecamera;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.ImageFormat;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * STRIKE CAMERA — a câmera da máquina (webcam USB, ex.: Sigma) na TV Box.
 *
 * O CameraServer do Godot 4.6 no Android ignora câmeras EXTERNAS (USB):
 * este plugin abre qualquer câmera pela Camera2 (preferindo a externa) e,
 * se a TV Box só tiver o driver antigo, pela Camera1. Cada quadro chega
 * como dois planos (Y e UV intercalado, 4:2:0) que o jogo converte em cor
 * na placa de vídeo (shaders/camera.gdshader, tipo 3).
 *
 * GDScript:  var c = Engine.get_singleton("StrikeCamera")
 *            c.listar() -> texto; c.abrir("auto", 640, 480); c.quadros();
 *            c.plano_y(); c.plano_uv(); c.largura(); c.altura(); c.fechar()
 */
public class StrikeCamera extends GodotPlugin {

	private final Object trava = new Object();
	private HandlerThread linha;
	private Handler alca;
	private CameraManager gerente;
	private CameraDevice dispositivo;
	private CameraCaptureSession sessao;
	private ImageReader leitor;
	@SuppressWarnings("deprecation")
	private android.hardware.Camera camera1;
	private SurfaceTexture textura1;

	private byte[] y = new byte[0];
	private byte[] uv = new byte[0];
	private int w = 0;
	private int h = 0;
	private int contador = 0;
	private volatile String estado = "parada";
	private int pedidoW = 640;
	private int pedidoH = 480;

	public StrikeCamera(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "StrikeCamera";
	}

	// ------------------------------------------------------------ consulta
	@UsedByGodot
	public String estado() {
		return estado;
	}

	@UsedByGodot
	public boolean tem_permissao() {
		Context c = getContext();
		if (c == null) {
			return false;
		}
		if (Build.VERSION.SDK_INT < 23) {
			return true;
		}
		return c.checkSelfPermission(android.Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
	}

	/** Uma linha por câmera: "id|lado|api" (lado: externa, frente, tras). */
	@UsedByGodot
	@SuppressWarnings("deprecation")
	public String listar() {
		StringBuilder sb = new StringBuilder();
		CameraManager m = gerente();
		if (m != null) {
			try {
				for (String id : m.getCameraIdList()) {
					sb.append(id).append('|').append(lado2(m, id)).append("|2\n");
				}
			} catch (Exception e) {
				sb.append("#erro camera2: ").append(e.getMessage()).append('\n');
			}
		}
		try {
			int n = android.hardware.Camera.getNumberOfCameras();
			for (int i = 0; i < n; i++) {
				android.hardware.Camera.CameraInfo info = new android.hardware.Camera.CameraInfo();
				android.hardware.Camera.getCameraInfo(i, info);
				String lado = info.facing == android.hardware.Camera.CameraInfo.CAMERA_FACING_FRONT ? "frente" : "tras";
				sb.append("c1:").append(i).append('|').append(lado).append("|1\n");
			}
		} catch (Exception e) {
			sb.append("#erro camera1: ").append(e.getMessage()).append('\n');
		}
		return sb.toString();
	}

	@UsedByGodot
	public int quadros() {
		synchronized (trava) {
			return contador;
		}
	}

	@UsedByGodot
	public int largura() {
		synchronized (trava) {
			return w;
		}
	}

	@UsedByGodot
	public int altura() {
		synchronized (trava) {
			return h;
		}
	}

	@UsedByGodot
	public byte[] plano_y() {
		synchronized (trava) {
			return y;
		}
	}

	@UsedByGodot
	public byte[] plano_uv() {
		synchronized (trava) {
			return uv;
		}
	}

	// ------------------------------------------------------------ ligar
	/**
	 * Abre a câmera. id: "auto" (externa > qualquer Camera2 > Camera1),
	 * um id da Camera2 ou "c1:N" (Camera1). Volta logo; o resultado aparece
	 * em estado() ("ligando", "ok", "erro ...") e quadros() começa a subir.
	 */
	@UsedByGodot
	public boolean abrir(final String id, int largura, int altura) {
		fechar();
		if (!tem_permissao()) {
			estado = "sem permissao";
			return false;
		}
		pedidoW = largura > 0 ? largura : 640;
		pedidoH = altura > 0 ? altura : 480;
		linha = new HandlerThread("StrikeCamera");
		linha.start();
		alca = new Handler(linha.getLooper());
		estado = "ligando";
		alca.post(new Runnable() {
			@Override
			public void run() {
				if (id.startsWith("c1:")) {
					abrirCamera1(Integer.parseInt(id.substring(3)));
					return;
				}
				String escolhida = "auto".equals(id) ? escolher2() : id;
				if (escolhida != null) {
					abrirCamera2(escolhida, true);
				} else {
					abrirCamera1(0);
				}
			}
		});
		return true;
	}

	@UsedByGodot
	@SuppressWarnings("deprecation")
	public void fechar() {
		try {
			if (sessao != null) {
				sessao.close();
			}
		} catch (Exception ignored) {
		}
		sessao = null;
		try {
			if (dispositivo != null) {
				dispositivo.close();
			}
		} catch (Exception ignored) {
		}
		dispositivo = null;
		try {
			if (leitor != null) {
				leitor.close();
			}
		} catch (Exception ignored) {
		}
		leitor = null;
		try {
			if (camera1 != null) {
				camera1.setPreviewCallback(null);
				camera1.stopPreview();
				camera1.release();
			}
		} catch (Exception ignored) {
		}
		camera1 = null;
		if (textura1 != null) {
			textura1.release();
			textura1 = null;
		}
		if (linha != null) {
			linha.quitSafely();
			linha = null;
			alca = null;
		}
		estado = "parada";
	}

	@Override
	public void onMainPause() {
		// a TV Box saiu do jogo: solta a câmera para outros apps
		fechar();
	}

	@Override
	public void onMainDestroy() {
		fechar();
	}

	// ------------------------------------------------------------ Camera2
	private CameraManager gerente() {
		if (gerente == null) {
			Activity a = getActivity();
			if (a != null) {
				gerente = (CameraManager) a.getSystemService(Context.CAMERA_SERVICE);
			}
		}
		return gerente;
	}

	private static String lado2(CameraManager m, String id) {
		try {
			Integer f = m.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
			if (f == null) {
				return "externa";
			}
			if (f == CameraCharacteristics.LENS_FACING_FRONT) {
				return "frente";
			}
			if (f == CameraCharacteristics.LENS_FACING_BACK) {
				return "tras";
			}
			return "externa";
		} catch (Exception e) {
			return "externa";
		}
	}

	/** A webcam USB (externa) primeiro; senão a primeira que houver. */
	private String escolher2() {
		CameraManager m = gerente();
		if (m == null) {
			return null;
		}
		try {
			String[] ids = m.getCameraIdList();
			for (String id : ids) {
				if ("externa".equals(lado2(m, id))) {
					return id;
				}
			}
			return ids.length > 0 ? ids[0] : null;
		} catch (Exception e) {
			return null;
		}
	}

	private Size tamanho2(String id) {
		try {
			StreamConfigurationMap mapa = gerente().getCameraCharacteristics(id)
					.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
			Size[] tams = mapa != null ? mapa.getOutputSizes(ImageFormat.YUV_420_888) : null;
			if (tams == null || tams.length == 0) {
				return new Size(pedidoW, pedidoH);
			}
			Size melhor = tams[0];
			long nota = Long.MAX_VALUE;
			for (Size s : tams) {
				long n = Math.abs((long) s.getWidth() * s.getHeight() - (long) pedidoW * pedidoH);
				if (n < nota) {
					nota = n;
					melhor = s;
				}
			}
			return melhor;
		} catch (Exception e) {
			return new Size(pedidoW, pedidoH);
		}
	}

	@SuppressWarnings("MissingPermission")
	private void abrirCamera2(final String id, final boolean tentarCamera1) {
		CameraManager m = gerente();
		if (m == null) {
			if (tentarCamera1) {
				abrirCamera1(0);
			}
			return;
		}
		final Size tam = tamanho2(id);
		try {
			m.openCamera(id, new CameraDevice.StateCallback() {
				@Override
				public void onOpened(CameraDevice d) {
					dispositivo = d;
					iniciarSessao(d, tam, tentarCamera1);
				}

				@Override
				public void onDisconnected(CameraDevice d) {
					d.close();
					dispositivo = null;
					estado = "desconectada";
				}

				@Override
				public void onError(CameraDevice d, int erro) {
					d.close();
					dispositivo = null;
					estado = "erro camera2 " + erro;
					if (tentarCamera1) {
						abrirCamera1(0);
					}
				}
			}, alca);
		} catch (Exception e) {
			estado = "erro camera2: " + e.getMessage();
			if (tentarCamera1) {
				abrirCamera1(0);
			}
		}
	}

	private void iniciarSessao(final CameraDevice d, Size tam, final boolean tentarCamera1) {
		try {
			leitor = ImageReader.newInstance(tam.getWidth(), tam.getHeight(), ImageFormat.YUV_420_888, 3);
			leitor.setOnImageAvailableListener(new ImageReader.OnImageAvailableListener() {
				@Override
				public void onImageAvailable(ImageReader r) {
					Image img = null;
					try {
						img = r.acquireLatestImage();
						if (img != null) {
							guardarYuv(img);
						}
					} catch (Exception ignored) {
					} finally {
						if (img != null) {
							img.close();
						}
					}
				}
			}, alca);
			List<android.view.Surface> alvos = new ArrayList<android.view.Surface>(Arrays.asList(leitor.getSurface()));
			d.createCaptureSession(alvos, new CameraCaptureSession.StateCallback() {
				@Override
				public void onConfigured(CameraCaptureSession s) {
					sessao = s;
					try {
						CaptureRequest.Builder b = d.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
						b.addTarget(leitor.getSurface());
						s.setRepeatingRequest(b.build(), null, alca);
						estado = "ok camera2";
					} catch (CameraAccessException e) {
						estado = "erro pedido: " + e.getMessage();
					} catch (Exception e) {
						estado = "erro pedido: " + e.getMessage();
					}
				}

				@Override
				public void onConfigureFailed(CameraCaptureSession s) {
					estado = "erro sessao";
					if (tentarCamera1) {
						d.close();
						dispositivo = null;
						abrirCamera1(0);
					}
				}
			}, alca);
		} catch (Exception e) {
			estado = "erro sessao: " + e.getMessage();
		}
	}

	/** Copia Y e monta o UV intercalado (U, V) respeitando o passo de cada plano. */
	private void guardarYuv(Image img) {
		int W = img.getWidth();
		int H = img.getHeight();
		Image.Plane[] p = img.getPlanes();
		ByteBuffer by = p[0].getBuffer();
		int rsY = p[0].getRowStride();
		byte[] nY = new byte[W * H];
		for (int r = 0; r < H; r++) {
			by.position(r * rsY);
			by.get(nY, r * W, Math.min(W, by.remaining()));
		}
		ByteBuffer bu = p[1].getBuffer();
		ByteBuffer bv = p[2].getBuffer();
		int rsU = p[1].getRowStride();
		int psU = p[1].getPixelStride();
		int rsV = p[2].getRowStride();
		int psV = p[2].getPixelStride();
		int W2 = W / 2;
		int H2 = H / 2;
		byte[] nUV = new byte[W2 * H2 * 2];
		int limU = bu.limit();
		int limV = bv.limit();
		for (int r = 0; r < H2; r++) {
			int bU = r * rsU;
			int bV = r * rsV;
			int o = r * W2 * 2;
			for (int c = 0; c < W2; c++) {
				int iu = bU + c * psU;
				int iv = bV + c * psV;
				nUV[o + c * 2] = iu < limU ? bu.get(iu) : (byte) 128;
				nUV[o + c * 2 + 1] = iv < limV ? bv.get(iv) : (byte) 128;
			}
		}
		synchronized (trava) {
			y = nY;
			uv = nUV;
			w = W;
			h = H;
			contador++;
		}
	}

	// ------------------------------------------------------------ Camera1
	@SuppressWarnings("deprecation")
	private void abrirCamera1(int indice) {
		try {
			if (android.hardware.Camera.getNumberOfCameras() <= indice) {
				if (!estado.startsWith("erro")) {
					estado = "sem camera";
				}
				return;
			}
			camera1 = android.hardware.Camera.open(indice);
			android.hardware.Camera.Parameters prm = camera1.getParameters();
			android.hardware.Camera.Size melhor = null;
			long nota = Long.MAX_VALUE;
			for (android.hardware.Camera.Size s : prm.getSupportedPreviewSizes()) {
				long n = Math.abs((long) s.width * s.height - (long) pedidoW * pedidoH);
				if (n < nota) {
					nota = n;
					melhor = s;
				}
			}
			if (melhor != null) {
				prm.setPreviewSize(melhor.width, melhor.height);
			}
			prm.setPreviewFormat(ImageFormat.NV21);
			camera1.setParameters(prm);
			final android.hardware.Camera.Size usado = camera1.getParameters().getPreviewSize();
			textura1 = new SurfaceTexture(10);
			camera1.setPreviewTexture(textura1);
			camera1.setPreviewCallback(new android.hardware.Camera.PreviewCallback() {
				@Override
				public void onPreviewFrame(byte[] dados, android.hardware.Camera c) {
					guardarNv21(dados, usado.width, usado.height);
				}
			});
			camera1.startPreview();
			estado = "ok camera1";
		} catch (Exception e) {
			estado = "erro camera1: " + e.getMessage();
			if (camera1 != null) {
				try {
					camera1.release();
				} catch (Exception ignored) {
				}
				camera1 = null;
			}
		}
	}

	/** NV21: Y inteiro e depois V,U intercalados — vira Y + (U,V). */
	private void guardarNv21(byte[] d, int W, int H) {
		if (d == null || d.length < W * H * 3 / 2) {
			return;
		}
		byte[] nY = new byte[W * H];
		System.arraycopy(d, 0, nY, 0, W * H);
		int n = (W / 2) * (H / 2);
		byte[] nUV = new byte[n * 2];
		int base = W * H;
		for (int i = 0; i < n; i++) {
			nUV[i * 2] = d[base + i * 2 + 1];
			nUV[i * 2 + 1] = d[base + i * 2];
		}
		synchronized (trava) {
			y = nY;
			uv = nUV;
			w = W;
			h = H;
			contador++;
		}
	}
}
