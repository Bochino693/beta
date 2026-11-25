package com.lazersport.strikeserial;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.role.RoleManager;
import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import org.godotengine.godot.utils.ProcessPhoenix;

import java.util.List;

/**
 * O JOGO ABRE SOZINHO AO LIGAR A TV - de qualquer jeito que ela seja ligada.
 *
 * 1. TELA INICIAL: o jogo é uma tela inicial do Android (StrikeInicioAtivo).
 *    Escolhido como a tela inicial da TV, é ele que o Android abre ao ligar
 *    na tomada, ao voltar para o início e a cada HOME. estado() diz se já é;
 *    escolher() abre a escolha do Android (o papel HOME do Android 10+, os
 *    ajustes da tela inicial ou a janela "Sempre / Só uma vez") - o jogo
 *    pede sozinho na tela de espera enquanto não for (sozinho = true).
 * 2. VOLTA DA ESPERA: desligada pelo CONTROLE, a TV não desliga de verdade
 *    (fica em espera) e nada "liga" de novo - um app de "abrir ao ligar" não
 *    percebe nada. Com o processo do jogo vivo (mesmo fechado ou atrás de
 *    outro app), ouvirTela() percebe a tela apagar e acender: depois de 10 s
 *    ou mais apagada, o jogo reinicia do zero (como ao ligar na tomada) e
 *    vem para a frente, sem a imagem travada da placa de vídeo depois da
 *    espera. Ligada na tomada, StrikeLigou também abre o jogo.
 * 3. SAÍDA DO OPERADOR: sairParaTv() abre a tela inicial da própria TV (o
 *    menu do operador, ou HOME 5 vezes seguidas - pediuParaSair()).
 * 4. LIGOU (StrikeLigou): abrirAoLigar() - a segunda garantia, para a TV
 *    que ainda não tem o jogo como tela inicial.
 *
 * NADA DAQUI ABRE SOZINHO uma tela do Android (ajustes, escolha da tela
 * inicial): na máquina sem controle remoto o jogo ficaria parado atrás dela.
 * Só a INSTALAÇÃO (com alguém apertando OK) e o menu do operador pedem.
 */
final class InicioDaTv {

	private static final String TAG = "StrikeSerial";
	static final int PEDIDO_PAPEL = 7501;
	private static final String PREFS = "strike_inicio";
	private static final int VEZES_PARA_SAIR = 5;
	private static final long JANELA_SAIR_MS = 10000;
	/** HOME só conta para sair com a TV ligada há mais disto (no boot o Android abre a tela inicial várias vezes) */
	private static final long SEM_CONTAR_AO_LIGAR_MS = 120000;
	private static final long APAGADA_PARA_REINICIAR_MS = 10000;
	private static final long ESPERA_AO_ACENDER_MS = 1500;

	private static final String CANAL = "strike_inicio";
	private static final int AVISO_ID = 7601;
	private static final int PEDIDO_AVISO = 7602;
	private static final long[] TENTATIVAS_MS = {0, 3000, 7000};

	private static long pedidoEm = 0;
	private static boolean pedidoSozinho = false;
	private static long apagouEm = 0;
	private static BroadcastReceiver tela;
	/** O jogo está na frente (StrikeSerial: onMainResume / onMainPause). */
	static volatile boolean naFrente = false;

	private InicioDaTv() {
	}

	private static Intent home() {
		return new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
	}

	/** Abre uma tela de outro app; false se a TV não tem essa tela. */
	private static boolean abrir(Context c, Intent i) {
		try {
			i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			c.startActivity(i);
			return true;
		} catch (ActivityNotFoundException e) {
			return false;
		} catch (Throwable t) {
			Log.i(TAG, "inicio: " + t);
			return false;
		}
	}

	/** O jogo, como o lançador o abre (só traz para a frente se já está aberto). */
	static void abrirJogo(Context c) {
		Intent jogo = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
		if (jogo != null) {
			jogo.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
			c.startActivity(jogo);
		}
	}

	// ------------------------------------------------------------ ligou
	/** O Android deixa um aviso de "ligou" abrir uma tela? (até o 9 sempre; 10+ só com "sobrepor") */
	static boolean podeAbrirDeFundo(Context c) {
		if (Build.VERSION.SDK_INT < 29) {
			return true;
		}
		try {
			return Settings.canDrawOverlays(c);
		} catch (Throwable t) {
			return false;
		}
	}

	/** A TV ligou: abre o jogo (3 tentativas) e, se não veio, o aviso que abre. */
	static void abrirAoLigar(final Context c, final BroadcastReceiver.PendingResult fim) {
		if (estado(c).equals("jogo")) {
			// o jogo é a tela inicial: o próprio Android já abriu (e ela fica
			// por baixo do jogo) - nada de abrir de novo nem de aviso
			if (fim != null) {
				fim.finish();
			}
			return;
		}
		final Handler h = new Handler(Looper.getMainLooper());
		for (int k = 0; k < TENTATIVAS_MS.length; k++) {
			final boolean ultima = k == TENTATIVAS_MS.length - 1;
			h.postDelayed(new Runnable() {
				@Override
				public void run() {
					try {
						if (!naFrente) {
							abrirJogo(c);
						}
						if (ultima && !naFrente && !podeAbrirDeFundo(c)) {
							avisar(c);
						}
					} catch (Throwable t) {
						Log.i(TAG, "inicio: ligou: " + t);
					} finally {
						if (ultima && fim != null) {
							fim.finish();
						}
					}
				}
			}, TENTATIVAS_MS[k]);
		}
	}

	/**
	 * Android 10+ sem "sobrepor a outros apps": um aviso (notificação) que
	 * abre o jogo - na tela cheia quando o Android deixa, senão no canto
	 * ("toque para abrir").
	 */
	private static void avisar(Context c) {
		if (Build.VERSION.SDK_INT < 26) {
			return;
		}
		NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm == null) {
			return;
		}
		Intent jogo = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
		if (jogo == null) {
			return;
		}
		jogo.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
		NotificationChannel canal = new NotificationChannel(CANAL, "Abrir o jogo ao ligar", NotificationManager.IMPORTANCE_HIGH);
		nm.createNotificationChannel(canal);
		PendingIntent pi = PendingIntent.getActivity(c, PEDIDO_AVISO, jogo,
				PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
		Notification n = new Notification.Builder(c, CANAL)
				.setSmallIcon(android.R.drawable.ic_media_play)
				.setContentTitle("Strike Kids")
				.setContentText("Toque para abrir o jogo")
				.setCategory(Notification.CATEGORY_ALARM)
				.setContentIntent(pi)
				.setFullScreenIntent(pi, true)
				.setAutoCancel(true)
				.build();
		try {
			nm.notify(AVISO_ID, n);
		} catch (Throwable t) {
			Log.i(TAG, "inicio: aviso: " + t);
		}
	}

	/** O jogo veio para a frente: o aviso de abrir some. */
	static void jogoNaFrente(Context c) {
		naFrente = true;
		try {
			NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
			if (nm != null) {
				nm.cancel(AVISO_ID);
			}
		} catch (Throwable ignored) {
		}
	}

	// ------------------------------------------------------------ instalação
	/**
	 * O que falta para o jogo abrir sozinho e direto ao ligar, separado por
	 * vírgula: "inicio" (não é a tela inicial), "sobrepor" (Android 10+ sem
	 * "sobrepor a outros apps", e o jogo não é a tela inicial).
	 */
	static String falta(Activity a) {
		StringBuilder sb = new StringBuilder();
		boolean inicio = estado(a).equals("jogo");
		if (!inicio) {
			sb.append("inicio");
		}
		if (!inicio && !podeAbrirDeFundo(a) && telaDeSobrepor(a) != null) {
			sb.append(sb.length() > 0 ? "," : "").append("sobrepor");
		}
		return sb.toString();
	}

	private static Intent telaDeSobrepor(Context c) {
		if (Build.VERSION.SDK_INT < 23) {
			return null;
		}
		Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + c.getPackageName()));
		if (i.resolveActivity(c.getPackageManager()) != null) {
			return i;
		}
		i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
		return i.resolveActivity(c.getPackageManager()) != null ? i : null;
	}

	/** Abre a página "sobrepor a outros apps" do jogo: "ajustes" ou "" (a TV não tem). */
	static String pedirSobrepor(Activity a) {
		Intent i = telaDeSobrepor(a);
		return i != null && abrir(a, i) ? "ajustes" : "";
	}

	// ------------------------------------------------------------ tela inicial
	/** A tela inicial que o Android abre hoje (null, ou a janela de escolha). */
	private static ResolveInfo padrao(Context c) {
		return c.getPackageManager().resolveActivity(home(), PackageManager.MATCH_DEFAULT_ONLY);
	}

	private static boolean ehCandidata(Context c, ResolveInfo ri) {
		List<ResolveInfo> todas = c.getPackageManager().queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY);
		for (ResolveInfo r : todas) {
			if (r.activityInfo.packageName.equals(ri.activityInfo.packageName) && r.activityInfo.name.equals(ri.activityInfo.name)) {
				return true;
			}
		}
		return false;
	}

	/** "jogo" (a TV já abre o jogo), "escolher" (o Android ainda pergunta) ou "outra|Nome". */
	static String estado(Context c) {
		ResolveInfo ri = padrao(c);
		if (ri == null || ri.activityInfo == null) {
			return "escolher";
		}
		if (ri.activityInfo.packageName.equals(c.getPackageName())) {
			return "jogo";
		}
		// sem uma escolhida, o Android devolve a própria janela de escolha
		if (!ehCandidata(c, ri)) {
			return "escolher";
		}
		return "outra|" + ri.loadLabel(c.getPackageManager());
	}

	/**
	 * Abre a escolha da tela inicial: "ja" (já é o jogo), "papel" (a janela do
	 * Android 10+), "ajustes", "escolha" (a janela "Sempre / Só uma vez"),
	 * "app" (a página da tela inicial da TV: "Limpar padrões"), "config" ou ""
	 * (nada abriu). sozinho (o jogo pedindo na tela de espera): só as janelas
	 * de escolha, nunca a página do app nem os ajustes gerais.
	 */
	static String escolher(Activity a, boolean sozinho) {
		String agora = estado(a);
		if (agora.equals("jogo")) {
			return "ja";
		}
		pedidoSozinho = sozinho;
		if (Build.VERSION.SDK_INT >= 29 && pedirPapel(a)) {
			return "papel";
		}
		return semPapel(a, agora, sozinho);
	}

	private static boolean pedirPapel(Activity a) {
		try {
			RoleManager rm = a.getSystemService(RoleManager.class);
			if (rm == null || !rm.isRoleAvailable(RoleManager.ROLE_HOME) || rm.isRoleHeld(RoleManager.ROLE_HOME)) {
				return false;
			}
			pedidoEm = SystemClock.elapsedRealtime();
			a.startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), PEDIDO_PAPEL);
			return true;
		} catch (Throwable t) {
			Log.i(TAG, "inicio: papel: " + t);
			return false;
		}
	}

	/** A janela do papel voltou: se ela nem apareceu (TV sem essa janela), segue pelos ajustes. */
	static void depoisDoPapel(Activity a, int resultado) {
		if (resultado == Activity.RESULT_OK || SystemClock.elapsedRealtime() - pedidoEm > 1500) {
			return;
		}
		String agora = estado(a);
		if (!agora.equals("jogo")) {
			semPapel(a, agora, pedidoSozinho);
		}
	}

	private static String semPapel(Activity a, String agora, boolean sozinho) {
		if (abrir(a, new Intent(Settings.ACTION_HOME_SETTINGS))) {
			return "ajustes";
		}
		if (agora.equals("escolher") && abrir(a, home())) {
			return "escolha";
		}
		if (sozinho) {
			return "";
		}
		ResolveInfo ri = padrao(a);
		if (ri != null && ri.activityInfo != null && !ri.activityInfo.packageName.equals(a.getPackageName())
				&& abrir(a, new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ri.activityInfo.packageName)))) {
			return "app";
		}
		if (abrir(a, new Intent(Settings.ACTION_SETTINGS))) {
			return "config";
		}
		return "";
	}

	// ------------------------------------------------------------ saída
	/** A tela inicial da própria TV (a de maior prioridade que não é o jogo), ou null. */
	private static ResolveInfo outraTela(Context c) {
		PackageManager pm = c.getPackageManager();
		ResolveInfo melhor = null;
		for (ResolveInfo r : pm.queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY)) {
			if (r.activityInfo == null || r.activityInfo.packageName.equals(c.getPackageName())) {
				continue;
			}
			// a "FallbackHome" dos Ajustes (só a do começo do boot) tem prioridade -1000
			if (melhor == null || r.priority > melhor.priority
					|| (r.priority == melhor.priority && sistema(r) && !sistema(melhor))) {
				melhor = r;
			}
		}
		return melhor;
	}

	private static boolean sistema(ResolveInfo r) {
		return (r.activityInfo.applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0;
	}

	/** Abre a tela inicial da própria TV (ou os ajustes): o nome dela, "config" ou "". */
	static String sairParaTv(Context c) {
		ResolveInfo outra = outraTela(c);
		if (outra != null) {
			Intent i = home().setClassName(outra.activityInfo.packageName, outra.activityInfo.name)
					.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
			if (abrir(c, i)) {
				return outra.loadLabel(c.getPackageManager()).toString();
			}
		}
		return abrir(c, new Intent(Settings.ACTION_SETTINGS)) ? "config" : "";
	}

	/**
	 * HOME 5 vezes em 10 s (ou o jogo caindo sem parar): true = sair para a tela da TV.
	 *
	 * A conta é só DESTA vez que a TV ligou. O relógio usado (elapsedRealtime)
	 * recomeça do zero a cada vez que a TV liga, e a TV abre a tela inicial
	 * sempre mais ou menos no mesmo segundo: sem separar por ligada, a
	 * abertura de cada dia somava com a do dia anterior e, na 5ª vez que a TV
	 * ligava, o jogo "saía para a tela da TV" sozinho em vez de abrir.
	 */
	static boolean pediuParaSair(Context c) {
		SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		long agora = SystemClock.elapsedRealtime();
		long ligada = ligada(c);
		long desde = p.getLong("desde", 0);
		int vezes = p.getInt("vezes", 0);
		if (ligada != p.getLong("ligada", Long.MIN_VALUE) || agora < desde || agora - desde > JANELA_SAIR_MS) {
			desde = agora;
			vezes = 0;
		}
		// no começo (o próprio Android abrindo a tela inicial, o lançador da
		// TV montando, o Arduino e a câmera aparecendo no USB) não conta
		if (agora < SEM_CONTAR_AO_LIGAR_MS) {
			vezes = 0;
		} else {
			vezes++;
		}
		boolean sair = vezes >= VEZES_PARA_SAIR;
		p.edit().putLong("ligada", ligada).putLong("desde", sair ? 0 : desde).putInt("vezes", sair ? 0 : vezes).commit();
		return sair;
	}

	/**
	 * Um número que muda a cada vez que a TV liga: o contador de ligadas do
	 * Android (7+, boot_count) ou, sem ele, o minuto em que ela ligou
	 * (negativo, para não se confundir com o contador).
	 */
	private static long ligada(Context c) {
		try {
			int n = Settings.Global.getInt(c.getContentResolver(), "boot_count", -1);
			if (n >= 0) {
				return n;
			}
		} catch (Throwable ignored) {
		}
		long minuto = (System.currentTimeMillis() - SystemClock.elapsedRealtime()) / 60000L;
		return -1 - Math.abs(minuto);
	}

	// ------------------------------------------------------------ volta da espera
	/**
	 * Tela apagada 10 s ou mais e acesa de novo = o jogo reinicia do zero.
	 * Fica ouvindo enquanto o processo do jogo viver (mesmo com o jogo
	 * fechado ou atrás de outro app).
	 */
	static void ouvirTela(Activity atividade) {
		if (tela != null) {
			return;
		}
		final Context app = atividade.getApplicationContext();
		tela = new BroadcastReceiver() {
			@Override
			public void onReceive(Context c, Intent i) {
				if (Intent.ACTION_SCREEN_OFF.equals(i.getAction())) {
					apagouEm = SystemClock.elapsedRealtime();
					return;
				}
				long apagada = apagouEm > 0 ? SystemClock.elapsedRealtime() - apagouEm : 0;
				apagouEm = 0;
				if (apagada < APAGADA_PARA_REINICIAR_MS) {
					return;
				}
				Log.i(TAG, "inicio: a TV voltou da espera (" + apagada / 1000 + " s): o jogo reinicia");
				new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
					@Override
					public void run() {
						try {
							ProcessPhoenix.triggerRebirth(app);
						} catch (Throwable t) {
							Log.i(TAG, "inicio: reiniciar: " + t);
						}
					}
				}, ESPERA_AO_ACENDER_MS);
			}
		};
		IntentFilter f = new IntentFilter(Intent.ACTION_SCREEN_OFF);
		f.addAction(Intent.ACTION_SCREEN_ON);
		try {
			app.registerReceiver(tela, f);
		} catch (Throwable t) {
			tela = null;
			Log.i(TAG, "inicio: tela: " + t);
		}
	}
}
