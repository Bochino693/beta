package com.lazersport.strikeserial;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * A TV LIGOU (na tomada): abre o jogo, como o "Launch on Boot" fazia - sem
 * precisar de outro app. Com o jogo escolhido como tela inicial
 * (StrikeInicioAtivo) o Android já o abre sozinho; isto é a segunda
 * garantia (no Android 10+ o sistema pode barrar uma tela aberta daqui).
 * QUICKBOOT_POWERON: o "ligou" das TVs e TV Boxes com inicialização rápida.
 */
public class StrikeLigou extends BroadcastReceiver {
	@Override
	public void onReceive(Context c, Intent i) {
		try {
			Log.i("StrikeSerial", "inicio: a TV ligou (" + i.getAction() + "): abrindo o jogo");
			InicioDaTv.abrirJogo(c);
		} catch (Throwable t) {
			Log.i("StrikeSerial", "inicio: ligou: " + t);
		}
	}
}
