package com.lazersport.strikeserial;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

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
 *
 * O JOGO ABRE AO LIGAR, SEMPRE: o sistema chama este serviço a cada vez que
 * a TV liga (e o Android deixa um serviço de acessibilidade abrir o app -
 * as TVs com Android de TV não aceitam outro app como tela inicial e, do
 * Android 10 em diante, bloqueiam o "abrir ao ligar" comum). Assim que ele
 * sobe, o jogo abre; e se o lançador da TV aparecer depois (HOME do
 * controle, o jogo fechou), o jogo volta - a não ser que o operador tenha
 * saído pelo menu ("> SAIR PARA A TELA DA TV": 15 minutos sem voltar). Roda
 * num processo só dele (":auto"), separado do jogo.
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

	private final Handler h = new Handler(Looper.getMainLooper());
	private Set<String> lancadores;
	private long trazerEm = 0;

	private final Runnable trazer = new Runnable() {
		@Override
		public void run() {
			trazerJogo(false);
		}
	};

	private final Runnable trazerAoLigar = new Runnable() {
		@Override
		public void run() {
			trazerJogo(true);
		}
	};

	private final Runnable reconferir = new Runnable() {
		@Override
		public void run() {
			conferir();
		}
	};

	@Override
	protected void onServiceConnected() {
		super.onServiceConnected();
		// a TV acabou de ligar (ou o serviço foi ligado agora): o jogo abre
		h.postDelayed(trazerAoLigar, 2500);
		h.postDelayed(trazerAoLigar, 8000);
		// a janela do USB pode já estar aberta
		conferir();
		h.postDelayed(reconferir, 1500);
	}

	@Override
	public void onAccessibilityEvent(AccessibilityEvent e) {
		if (e == null || e.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
			return;
		}
		CharSequence cs = e.getPackageName();
		if (cs == null) {
			return;
		}
		String pkg = cs.toString();
		if (ehDoSistema(pkg)) {
			// a janela do USB: confere já e de novo (a da TV desliza e só
			// mostra os botões um instante depois)
			conferir();
			h.removeCallbacks(reconferir);
			h.postDelayed(reconferir, 600);
			h.postDelayed(reconferir, 1500);
		} else if (ehLancador(pkg)) {
			// o lançador da TV apareceu: o jogo volta (um pouquinho depois:
			// se foi só um piscar, nada acontece)
			h.removeCallbacks(trazer);
			h.postDelayed(trazer, 1500);
		}
	}

	/** As telas iniciais da TV (menos a do jogo e a "Android iniciando" dos Ajustes). */
	private boolean ehLancador(String pkg) {
		if (lancadores == null) {
			lancadores = new HashSet<String>();
			try {
				Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
				for (ResolveInfo r : getPackageManager().queryIntentActivities(home, 0)) {
					if (r.activityInfo != null) {
						lancadores.add(r.activityInfo.packageName);
					}
				}
			} catch (Throwable ignored) {
			}
			lancadores.remove(getPackageName());
			lancadores.remove("com.android.settings");
		}
		return lancadores.contains(pkg);
	}

	/**
	 * Traz o jogo para a frente - só se na frente está o lançador da TV (ou
	 * nada, ao ligar). Um app, os ajustes ou uma janela na frente: não briga.
	 */
	private void trazerJogo(boolean aoLigar) {
		try {
			if (InicioDaTv.operadorSaiu(this)) {
				return;
			}
			AccessibilityNodeInfo raiz = getRootInActiveWindow();
			String ativo = raiz != null && raiz.getPackageName() != null ? raiz.getPackageName().toString() : null;
			if (getPackageName().equals(ativo)) {
				return;   // o jogo já está na frente
			}
			if (ativo != null && !ehLancador(ativo) && !(aoLigar && ativo.equals("com.android.settings"))) {
				return;
			}
			long agora = android.os.SystemClock.elapsedRealtime();
			if (agora - trazerEm < 3000) {
				return;
			}
			trazerEm = agora;
			Log.i(TAG, "auto ok: o jogo volta para a frente (" + ativo + ")");
			InicioDaTv.abrirJogo(this);
		} catch (Throwable t) {
			Log.i(TAG, "auto ok: trazer: " + t);
		}
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
