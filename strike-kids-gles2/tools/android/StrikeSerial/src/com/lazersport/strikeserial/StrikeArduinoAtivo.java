package com.lazersport.strikeserial;

import android.app.Activity;
import android.os.Bundle;

/**
 * PERMISSÃO DO ARDUINO UMA VEZ SÓ - E VALE DEPOIS DE DESLIGAR.
 *
 * Com o filtro res/xml/strike_usb_arduino.xml, a janela do Android mostra
 * "Usar por padrão" / "Sempre": marcada uma vez, cada vez que o Arduino
 * aparece no USB o próprio Android DÁ A PERMISSÃO ao jogo e abre esta tela.
 *
 * POR QUE NÃO VALIA DEPOIS DE DESLIGAR A TV BOX (até a 7.7): o Arduino que já
 * está ligado quando a TV Box liga é visto pelo Android bem no começo do
 * boot, antes de o usuário ser "destravado" (Android 7+). Nesse instante o
 * Android só enxerga as telas marcadas como directBootAware - esta não era:
 * ele não achava quem tinha o "Sempre", não dava a permissão, e o jogo
 * ficava sem o Arduino (tirar e pôr o cabo depois resolvia). Agora ela é
 * directBootAware (manifesto): o Android acha, dá a permissão no boot, e
 * ela só fecha (o jogo ainda nem pode abrir nesse instante).
 *
 * Depois do boot (Arduino encaixado com o jogo aberto): a permissão já veio
 * com esta tela. O jogo já na frente não é chamado de novo (cada chamada
 * pausava o jogo por um instante: "travadinha"); fechado, ele abre.
 */
public class StrikeArduinoAtivo extends Activity {
	/**
	 * (8.7) SÓ A PERMISSÃO: esta tela existe para o Android dar a permissão
	 * do Arduino (com "Usar por padrão" marcado uma vez, ele dá sozinho a
	 * cada vez que liga). Ela NÃO abre o jogo - quem abre o jogo é a TELA
	 * INICIAL (o jogo é o "iniciar" da TV Box). Só fecha.
	 */
	@Override
	protected void onCreate(Bundle estado) {
		super.onCreate(estado);
		finish();
	}
}
