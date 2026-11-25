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
import android.view.accessibility.AccessibilityWindowInfo;

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

	/** procura a janela do USB até esta hora (elapsedRealtime) */
	private long vigiarAte = 0;

	/**
	 * VIGIA: confere todas as janelas a cada 0,4 s - a janela do USB nem
	 * sempre avisa ao abrir (ela aparece atrás, desliza, ou abriu antes de o
	 * serviço subir no boot). Depois do boot vigia 3 minutos; depois de
	 * qualquer janela nova, 20 s.
	 */
	private final Runnable vigia = new Runnable() {
		@Override
		public void run() {
			conferir();
			if (android.os.SystemClock.elapsedRealtime() < vigiarAte) {
				h.postDelayed(this, 400);
			}
		}
	};

	private void vigiar(long ms) {
		long ate = android.os.SystemClock.elapsedRealtime() + ms;
		if (ate > vigiarAte) {
			vigiarAte = ate;
		}
		h.removeCallbacks(vigia);
		h.post(vigia);
	}

	@Override
	protected void onServiceConnected() {
		super.onServiceConnected();
		// a TV acabou de ligar (ou o serviço foi ligado agora): o jogo abre
		h.postDelayed(trazerAoLigar, 2500);
		h.postDelayed(trazerAoLigar, 8000);
		// a janela do USB pode já estar aberta (ou abrir a qualquer momento
		// nestes primeiros minutos, enquanto a TV e o Arduino ligam)
		vigiar(180000);
	}

	@Override
	public void onAccessibilityEvent(AccessibilityEvent e) {
		if (e == null) {
			return;
		}
		if (e.getEventType() == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
			// uma janela apareceu/sumiu (a do USB pode ser um painel do lado)
			vigiar(20000);
			return;
		}
		if (e.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
			return;
		}
		CharSequence cs = e.getPackageName();
		if (cs == null) {
			return;
		}
		String pkg = cs.toString();
		if (!pkg.equals(getPackageName())) {
			// a janela do USB: confere já e de novo (a da TV desliza e só
			// mostra os botões um instante depois)
			conferir();
			vigiar(20000);
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

	/**
	 * Todas as janelas abertas (a do USB da TV pode ser um painel do lado,
	 * de qualquer pacote do sistema da TV, sem ser a janela "ativa").
	 */
	private void conferir() {
		try {
			List<AccessibilityWindowInfo> janelas = getWindows();
			if (janelas != null) {
				for (AccessibilityWindowInfo j : janelas) {
					AccessibilityNodeInfo r = j.getRoot();
					if (r != null && conferirJanela(r)) {
						return;
					}
				}
			}
		} catch (Throwable ignored) {
		}
		try {
			AccessibilityNodeInfo r = getRootInActiveWindow();
			if (r != null) {
				conferirJanela(r);
			}
		} catch (Throwable ignored) {
		}
	}

	/** true = era a janela do USB do Strike Kids e o OK foi apertado. */
	private boolean conferirJanela(AccessibilityNodeInfo raiz) {
		if (raiz.getPackageName() == null || getPackageName().contentEquals(raiz.getPackageName())) {
			return false;
		}
		// Só uma janela do SISTEMA (a do USB vem do sistema da TV, nunca de
		// outro app) - assim o OK não é apertado numa janela qualquer.
		String pkg = raiz.getPackageName().toString();
		if (!ehDoSistema(pkg) && !ehLancador(pkg)) {
			return false;
		}
		// É a janela do USB? Ela fala do aparelho USB/Serial, ou mostra o
		// nome do jogo. (Em português: "...acessório USB Serial"; outras
		// TVs mostram só o nome do aparelho, sem o nome do app - por isso
		// basta UMA destas pistas.)
		String nome = String.valueOf(getApplicationInfo().loadLabel(getPackageManager()));
		boolean fala = temTexto(raiz, "usb") || temTexto(raiz, "serial")
			|| temTexto(raiz, "acessóri") || temTexto(raiz, "acessori") || temTexto(raiz, "accessory")
			|| !raiz.findAccessibilityNodeInfosByText(nome).isEmpty();
		if (!fala) {
			return false;
		}
		// precisa ter um botão de aceitar (senão não é uma janela de pergunta)
		AccessibilityNodeInfo botao = acharBotao(raiz, 0);
		if (botao == null) {
			return false;
		}
		// "Sempre" / "Usar por padrão", nas TVs que têm a caixa
		marcarCaixas(raiz, 0);
		botao = acharBotao(raiz, 0);   // a caixa pode ter trocado os botões de lugar
		if (botao != null) {
			Log.i(TAG, "auto ok: aceitando a janela do USB (" + pkg + ")");
			botao.performAction(AccessibilityNodeInfo.ACTION_CLICK);
			// numa janela de ESCOLHA (lista de apps) o 1o toque escolhe o app;
			// confere de novo logo depois para apertar o OK que aparecer
			h.removeCallbacks(reconfere);
			h.postDelayed(reconfere, 350);
			h.postDelayed(reconfere, 1000);
			return true;
		}
		return false;
	}

	private final Runnable reconfere = new Runnable() {
		@Override
		public void run() {
			conferir();
		}
	};

	/** procura um texto (minúsculas) em qualquer pedaço da janela */
	private boolean temTexto(AccessibilityNodeInfo n, String alvo) {
		if (n == null) {
			return false;
		}
		CharSequence t = n.getText();
		if (t != null && t.toString().toLowerCase(Locale.ROOT).contains(alvo)) {
			return true;
		}
		CharSequence d = n.getContentDescription();
		if (d != null && d.toString().toLowerCase(Locale.ROOT).contains(alvo)) {
			return true;
		}
		for (int i = 0; i < n.getChildCount(); i++) {
			if (temTexto(n.getChild(i), alvo)) {
				return true;
			}
		}
		return false;
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
			String nomeApp = String.valueOf(getApplicationInfo().loadLabel(getPackageManager())).trim().toLowerCase(Locale.ROOT);
			boolean aceita = t.equals(nomeApp) && !nomeApp.isEmpty();
			for (String a : ACEITA) {
				if (t.equals(a)) {
					aceita = true;
				}
			}
			if (aceita) {
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
		for (int i = 0; i < n.getChildCount(); i++) {
			AccessibilityNodeInfo r = acharBotao(n.getChild(i), fundo + 1);
			if (r != null) {
				return r;
			}
		}
		return null;
	}
}
