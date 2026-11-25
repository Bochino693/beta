package com.lazersport.strikeserial;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Context;
import android.provider.Settings;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.List;
import java.util.Locale;

/**
 * O ARDUINO SEM PERGUNTAR, A CADA VEZ QUE A TV LIGA.
 *
 * Nas TVs com Android de TV a janela do USB ("Pretende abrir a app Strike
 * Kids para controlar o acessório USB Serial?") só tem OK e Cancelar - sem
 * a caixa "Sempre": o Android não guarda a resposta e pergunta de novo a
 * cada vez que liga (e sem controle remoto ninguém aperta OK).
 *
 * Este serviço de acessibilidade (ligado UMA vez: Ajustes > Acessibilidade
 * > "Strike Kids: Arduino automático", ou pelo adb no GERAR_APK
 * -TelaInicial) aperta OK sozinho nessa janela - SÓ nela: a janela do
 * sistema que fala do Strike Kids E de USB. Marca também o "Sempre", nas
 * TVs que têm. Nada mais é tocado.
 */
public class StrikeAutoOk extends AccessibilityService {

	private static final String TAG = "StrikeSerial";
	/** os botões que aceitam (nunca "Cancelar", "Negar"...) */
	private static final String[] ACEITA = {"ok", "permitir", "allow", "sim", "yes", "aceitar", "accept", "abrir", "open",
		"sempre", "always", "continuar", "continue"};

	/** Ligado nos ajustes de acessibilidade? */
	static boolean ligado(Context c) {
		try {
			String lista = Settings.Secure.getString(c.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
			if (lista == null) {
				return false;
			}
			ComponentName eu = new ComponentName(c, StrikeAutoOk.class);
			for (String s : lista.split(":")) {
				ComponentName cn = ComponentName.unflattenFromString(s.trim());
				if (eu.equals(cn)) {
					return true;
				}
			}
		} catch (Throwable ignored) {
		}
		return false;
	}

	@Override
	protected void onServiceConnected() {
		super.onServiceConnected();
		// a janela pode já estar aberta (a TV ligou antes de o serviço subir)
		conferir();
	}

	@Override
	public void onAccessibilityEvent(AccessibilityEvent e) {
		if (e == null) {
			return;
		}
		int t = e.getEventType();
		if (t != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && t != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
			return;
		}
		CharSequence pkg = e.getPackageName();
		if (pkg == null || !ehDoSistema(pkg.toString())) {
			return;
		}
		conferir();
	}

	@Override
	public void onInterrupt() {
	}

	private static boolean ehDoSistema(String pkg) {
		return pkg.contains("systemui") || pkg.equals("android") || pkg.contains("usb") || pkg.contains("permissioncontroller");
	}

	private void conferir() {
		AccessibilityNodeInfo raiz;
		try {
			raiz = getRootInActiveWindow();
		} catch (Throwable t) {
			return;
		}
		if (raiz == null || raiz.getPackageName() == null || !ehDoSistema(raiz.getPackageName().toString())) {
			return;
		}
		// só a janela do USB do Strike Kids
		String nome = String.valueOf(getApplicationInfo().loadLabel(getPackageManager()));
		if (raiz.findAccessibilityNodeInfosByText(nome).isEmpty()) {
			return;
		}
		if (raiz.findAccessibilityNodeInfosByText("USB").isEmpty() && raiz.findAccessibilityNodeInfosByText("usb").isEmpty()) {
			return;
		}
		// "Sempre" / "Usar por padrão", nas TVs que têm a caixa
		marcarCaixas(raiz, 0);
		AccessibilityNodeInfo botao = acharBotao(raiz, 0);
		if (botao != null) {
			Log.i(TAG, "auto ok: aceitando a janela do USB");
			botao.performAction(AccessibilityNodeInfo.ACTION_CLICK);
		}
	}

	private void marcarCaixas(AccessibilityNodeInfo n, int fundo) {
		if (n == null || fundo > 12) {
			return;
		}
		if (n.isCheckable() && !n.isChecked() && n.isEnabled()) {
			n.performAction(AccessibilityNodeInfo.ACTION_CLICK);
		}
		for (int i = 0; i < n.getChildCount(); i++) {
			marcarCaixas(n.getChild(i), fundo + 1);
		}
	}

	private AccessibilityNodeInfo acharBotao(AccessibilityNodeInfo n, int fundo) {
		if (n == null || fundo > 12) {
			return null;
		}
		CharSequence txt = n.getText();
		if (txt != null && !n.isCheckable()) {
			String t = txt.toString().trim().toLowerCase(Locale.ROOT);
			for (String a : ACEITA) {
				if (t.equals(a)) {
					// o próprio texto ou quem o contém é o botão
					AccessibilityNodeInfo b = n;
					for (int k = 0; b != null && !b.isClickable() && k < 3; k++) {
						b = b.getParent();
					}
					if (b != null && b.isClickable() && b.isEnabled()) {
						return b;
					}
				}
			}
		}
		for (int i = 0; i < n.getChildCount(); i++) {
			AccessibilityNodeInfo r = acharBotao(n.getChild(i), fundo + 1);
			if (r != null) {
				return r;
			}
		}
		return null;
	}
}
