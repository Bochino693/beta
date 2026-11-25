package com.lazersport.strikeserial;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * A TV LIGOU (na tomada) - ou o jogo acabou de ser atualizado: abre o jogo,
 * como o "Launch on Boot" fazia, sem precisar de outro app.
 *
 * O jeito certo é o jogo ser a TELA INICIAL da TV (StrikeInicioAtivo; a
 * INSTALAÇÃO da primeira vez pede): aí o Android abre o jogo direto, sem
 * nem carregar o lançador da TV Box. Isto aqui é a segunda garantia:
 *  - Android até o 9: abre o jogo na hora;
 *  - Android 10+: o sistema só deixa abrir daqui com a permissão "sobrepor a
 *    outros apps" (a instalação pede); sem ela tenta assim mesmo e, se o
 *    jogo não vier para a frente, mostra um aviso (notificação) que abre o
 *    jogo.
 * Tenta 3 vezes (na hora, 3 s e 7 s depois): TV Box lenta ainda está
 * montando o lançador dela quando o aviso de "ligou" chega.
 * QUICKBOOT_POWERON: o "ligou" das TVs e TV Boxes com inicialização rápida.
 */
public class StrikeLigou extends BroadcastReceiver {
	@Override
	public void onReceive(Context c, Intent i) {
		try {
			Log.i("StrikeSerial", "inicio: " + i.getAction() + ": abrindo o jogo");
			InicioDaTv.abrirAoLigar(c.getApplicationContext(), goAsync());
		} catch (Throwable t) {
			Log.i("StrikeSerial", "inicio: ligou: " + t);
		}
	}
}
