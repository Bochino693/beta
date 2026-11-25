package com.lazersport.strikeserial;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.KeyEvent;
import android.widget.TextView;

/**
 * O JOGO É A TELA INICIAL DA TV - como as máquinas de quiosque.
 *
 * Escolhida como a tela inicial ("Sempre"), é esta tela que o Android abre
 * ao ligar a TV Box: o lançador da TV nem carrega. Ela abre o jogo e FICA
 * POR BAIXO dele (fundo preto, "Abrindo o Strike Kids..."), sem fechar:
 *  - o Android não precisa abrir a tela inicial de novo (antes ela fechava
 *    na hora, o Android reabria várias vezes no boot e o jogo achava que era
 *    o operador apertando HOME - e saía para o lançador da TV);
 *  - se o jogo fechar ou cair, esta tela aparece e abre o jogo de novo;
 *  - HOME do controle: traz o jogo de volta.
 * O jogo fechou 5 vezes em 2 minutos (algo errado): para de abrir sozinho e
 * mostra o que fazer (OK abre de novo; VOLTAR 3 vezes = tela da TV).
 * HOME 5 vezes em 10 s (só com a TV ligada há mais de 2 minutos): a tela
 * inicial da própria TV - a saída do operador sem o menu.
 */
public class StrikeInicioAtivo extends Activity {

	private static final long INTERVALO_MIN_MS = 2500;
	private static final long JANELA_QUEDAS_MS = 120000;
	private static final int QUEDAS_MAX = 5;

	private final Handler h = new Handler(Looper.getMainLooper());
	private TextView texto;
	private long abriuEm = -100000;
	private final long[] aberturas = new long[QUEDAS_MAX];
	private int nAberturas = 0;
	private boolean parado = false;
	private int voltas = 0;
	private long voltaEm = 0;

	private final Runnable abrir = new Runnable() {
		@Override
		public void run() {
			abrirJogo(false);
		}
	};

	@Override
	protected void onCreate(Bundle estado) {
		super.onCreate(estado);
		texto = new TextView(this);
		texto.setBackgroundColor(Color.BLACK);
		texto.setTextColor(Color.rgb(255, 246, 168));
		texto.setTextSize(22);
		texto.setGravity(Gravity.CENTER);
		texto.setText("Abrindo o Strike Kids...");
		setContentView(texto);
	}

	@Override
	protected void onNewIntent(Intent i) {
		super.onNewIntent(i);
		setIntent(i);
		// HOME do controle (a tela inicial chamada de novo)
		try {
			if (InicioDaTv.pediuParaSair(this)) {
				InicioDaTv.sairParaTv(this);
				return;
			}
		} catch (Throwable ignored) {
		}
		parado = false;
		abrirJogo(true);
	}

	@Override
	protected void onResume() {
		super.onResume();
		// esta tela apareceu: o jogo não está na frente (abrindo, fechou ou caiu)
		if (!parado) {
			h.removeCallbacks(abrir);
			long espera = Math.max(0, INTERVALO_MIN_MS - (SystemClock.elapsedRealtime() - abriuEm));
			h.postDelayed(abrir, espera);
		}
	}

	@Override
	protected void onPause() {
		super.onPause();
		h.removeCallbacks(abrir);
	}

	private void abrirJogo(boolean pedido) {
		long agora = SystemClock.elapsedRealtime();
		if (!pedido) {
			// o jogo caindo sem parar: para e deixa o operador decidir
			int dentro = 0;
			for (int k = 0; k < nAberturas; k++) {
				if (agora - aberturas[k] < JANELA_QUEDAS_MS) {
					dentro++;
				}
			}
			if (dentro >= QUEDAS_MAX) {
				parado = true;
				texto.setText("O Strike Kids fechou " + QUEDAS_MAX + " vezes seguidas.\n\n"
						+ "OK: abrir de novo\nVOLTAR 3 vezes: tela da TV (ajustes)");
				return;
			}
			aberturas[nAberturas % QUEDAS_MAX] = agora;
			nAberturas++;
		}
		abriuEm = agora;
		texto.setText("Abrindo o Strike Kids...");
		try {
			InicioDaTv.abrirJogo(this);
		} catch (Throwable ignored) {
		}
	}

	@Override
	public boolean onKeyDown(int codigo, KeyEvent e) {
		if (codigo == KeyEvent.KEYCODE_DPAD_CENTER || codigo == KeyEvent.KEYCODE_ENTER
				|| codigo == KeyEvent.KEYCODE_BUTTON_A || codigo == KeyEvent.KEYCODE_BUTTON_START) {
			parado = false;
			nAberturas = 0;
			abrirJogo(true);
			return true;
		}
		if (codigo == KeyEvent.KEYCODE_BACK) {
			long agora = SystemClock.elapsedRealtime();
			voltas = agora - voltaEm < 4000 ? voltas + 1 : 1;
			voltaEm = agora;
			if (voltas >= 3) {
				voltas = 0;
				InicioDaTv.sairParaTv(this);
			}
			return true;   // a tela inicial não fecha com o VOLTAR
		}
		return super.onKeyDown(codigo, e);
	}

	@Override
	public void onBackPressed() {
		// (tratado no onKeyDown: a tela inicial nunca fecha)
	}
}
