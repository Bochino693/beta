package com.lazersport.strikeserial;

import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.DataInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.security.KeyPair;
import java.security.Signature;
import java.security.interfaces.RSAPublicKey;
import java.util.List;

/**
 * O ADB DA PRÓPRIA TV, FALADO PELO JOGO.
 *
 * Com a "Depuração USB" ligada (Opções do desenvolvedor), a TV aceita
 * comandos de adb pela rede, na porta 5555 - é o que o PREPARAR_TV.bat usa do
 * PC. O jogo se conecta nessa porta DENTRO da própria TV (127.0.0.1) e manda
 * os mesmos comandos: assim o jogo se põe sozinho como a única tela inicial,
 * sem PC e sem celular. A TV pergunta UMA vez "Permitir depuração?" (a chave
 * do jogo fica guardada; marcando "Sempre permitir", nunca mais pergunta).
 *
 * O protocolo (o mesmo do adb do PC, sem nada a mais): mensagens de 24 bytes
 * (comando, 2 argumentos, tamanho, soma dos bytes, comando ^ 0xffffffff) +
 * dados; CNXN abre a conversa, AUTH prova a chave (assinatura RSA do desafio
 * da TV ou, na 1a vez, a chave pública no formato do Android), OPEN
 * "shell:..." roda um comando e a saída volta em WRTE até o CLSE.
 *
 * Java puro (sem nada do Android). Vem do Dragon Bowling (AdbDaTv, testado
 * no PC contra um adbd simulado) - no Strike Kids, o comandoPreparar faz
 * também o Arduino (o serviço que aperta OK na janela do USB) e a câmera.
 */
final class AdbDaTv implements Closeable {

	private static final int CNXN = 0x4e584e43;
	private static final int AUTH = 0x48545541;
	private static final int OPEN = 0x4e45504f;
	private static final int OKAY = 0x59414b4f;
	private static final int CLSE = 0x45534c43;
	private static final int WRTE = 0x45545257;
	private static final int VERSAO = 0x01000001;
	private static final int MAIOR_PACOTE = 256 * 1024;
	private static final int AUTH_DESAFIO = 1;
	private static final int AUTH_ASSINATURA = 2;
	private static final int AUTH_CHAVE = 3;
	/** O começo da assinatura PKCS#1 de um SHA-1 (o adbd confere assim). */
	private static final byte[] SHA1_DIGEST_INFO = {0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14};

	private final Socket socket;
	private final DataInputStream entrada;
	private final OutputStream saida;
	private int proximoId = 1;

	static final class Pacote {
		int comando;
		int arg0;
		int arg1;
		byte[] dados;
	}

	private AdbDaTv(Socket s) throws IOException {
		socket = s;
		entrada = new DataInputStream(s.getInputStream());
		saida = s.getOutputStream();
	}

	/** Conecta no adb da TV; IOException se a depuração estiver desligada. */
	static AdbDaTv conectar(String host, int porta, int esperaMs) throws IOException {
		Socket s = new Socket();
		try {
			s.connect(new InetSocketAddress(host, porta), esperaMs);
			s.setTcpNoDelay(true);
			return new AdbDaTv(s);
		} catch (IOException e) {
			try {
				s.close();
			} catch (IOException ignored) {
			}
			throw e;
		}
	}

	@Override
	public void close() {
		try {
			socket.close();
		} catch (IOException ignored) {
		}
	}

	// ------------------------------------------------------------ mensagens
	void enviar(int comando, int arg0, int arg1, byte[] dados) throws IOException {
		if (dados == null) {
			dados = new byte[0];
		}
		int soma = 0;
		for (byte b : dados) {
			soma += b & 0xff;
		}
		ByteBuffer m = ByteBuffer.allocate(24 + dados.length).order(ByteOrder.LITTLE_ENDIAN);
		m.putInt(comando).putInt(arg0).putInt(arg1).putInt(dados.length).putInt(soma).putInt(comando ^ 0xffffffff);
		m.put(dados);
		saida.write(m.array());
		saida.flush();
	}

	Pacote receber() throws IOException {
		byte[] cab = new byte[24];
		entrada.readFully(cab);
		ByteBuffer b = ByteBuffer.wrap(cab).order(ByteOrder.LITTLE_ENDIAN);
		Pacote p = new Pacote();
		p.comando = b.getInt();
		p.arg0 = b.getInt();
		p.arg1 = b.getInt();
		int tamanho = b.getInt();
		b.getInt(); // soma (o adbd novo nem calcula)
		int magica = b.getInt();
		if (magica != (p.comando ^ 0xffffffff) || tamanho < 0 || tamanho > MAIOR_PACOTE) {
			throw new IOException("adb: mensagem estranha");
		}
		p.dados = new byte[tamanho];
		entrada.readFully(p.dados);
		return p;
	}

	// ------------------------------------------------------------ chave
	/**
	 * Entra no adb da TV. true = conectado. false = a TV não aceitou a chave
	 * (ninguém apertou "Permitir" em esperaPermitirMs, ou recusou).
	 * podeMostrarChave = false: nunca manda a chave pública (nada aparece na
	 * TV); só entra se a TV já confiar na chave do jogo.
	 */
	boolean entrar(KeyPair chave, String nome, boolean podeMostrarChave, int esperaMs, int esperaPermitirMs) throws IOException {
		socket.setSoTimeout(esperaMs);
		enviar(CNXN, VERSAO, MAIOR_PACOTE, "host::\0".getBytes("UTF-8"));
		boolean assinou = false;
		while (true) {
			Pacote p;
			try {
				p = receber();
			} catch (SocketTimeoutException e) {
				return false;
			}
			if (p.comando == CNXN) {
				return true;
			}
			if (p.comando != AUTH || p.arg0 != AUTH_DESAFIO) {
				throw new IOException("adb: resposta inesperada " + Integer.toHexString(p.comando));
			}
			if (!assinou) {
				assinou = true;
				enviar(AUTH, AUTH_ASSINATURA, 0, assinar(chave, p.dados));
			} else if (podeMostrarChave) {
				podeMostrarChave = false;
				// a TV mostra "Permitir depuração?" e espera alguém responder
				enviar(AUTH, AUTH_CHAVE, 0, chavePublicaAdb((RSAPublicKey) chave.getPublic(), nome));
				socket.setSoTimeout(esperaPermitirMs);
			} else {
				return false;
			}
		}
	}

	/** RSA PKCS#1 v1.5 do desafio de 20 bytes como um SHA-1 (RSA_sign(NID_sha1) do adbd). */
	static byte[] assinar(KeyPair chave, byte[] desafio) throws IOException {
		try {
			Signature s = Signature.getInstance("NONEwithRSA");
			s.initSign(chave.getPrivate());
			s.update(SHA1_DIGEST_INFO);
			s.update(desafio);
			return s.sign();
		} catch (Exception e) {
			throw new IOException("adb: assinatura: " + e);
		}
	}

	/**
	 * A chave pública no formato do adb do Android (RSAPublicKey do mincrypt:
	 * tamanho em palavras, n0inv, módulo e R² em palavras de 32 bits little
	 * endian, expoente), em base64, um espaço, o nome e um zero no fim.
	 */
	static byte[] chavePublicaAdb(RSAPublicKey k, String nome) throws IOException {
		BigInteger n = k.getModulus();
		int palavras = (n.bitLength() + 31) / 32;
		BigInteger r32 = BigInteger.ONE.shiftLeft(32);
		BigInteger n0inv = r32.subtract(n.mod(r32).modInverse(r32));
		BigInteger rr = BigInteger.ONE.shiftLeft(32 * palavras).modPow(BigInteger.valueOf(2), n);
		ByteBuffer b = ByteBuffer.allocate(4 + 4 + palavras * 8 + 4).order(ByteOrder.LITTLE_ENDIAN);
		b.putInt(palavras);
		b.putInt(n0inv.intValue());
		BigInteger t = n;
		for (int i = 0; i < palavras; i++) {
			b.putInt(t.mod(r32).intValue());
			t = t.shiftRight(32);
		}
		t = rr;
		for (int i = 0; i < palavras; i++) {
			b.putInt(t.mod(r32).intValue());
			t = t.shiftRight(32);
		}
		b.putInt(k.getPublicExponent().intValue());
		return (base64(b.array()) + " " + nome + "\0").getBytes("UTF-8");
	}

	// ------------------------------------------------------------ shell
	/** Roda um comando no shell da TV e devolve a saída (até o fim do comando). */
	String shell(String comando, int esperaMs) throws IOException {
		int local = proximoId++;
		socket.setSoTimeout(esperaMs);
		enviar(OPEN, local, 0, ("shell:" + comando + "\0").getBytes("UTF-8"));
		ByteArrayOutputStream texto = new ByteArrayOutputStream();
		while (true) {
			Pacote p = receber();
			if (p.arg1 != local) {
				continue;
			}
			if (p.comando == WRTE) {
				texto.write(p.dados);
				enviar(OKAY, local, p.arg0, null);
			} else if (p.comando == CLSE) {
				enviar(CLSE, local, p.arg0, null);
				break;
			}
			// OKAY: a TV abriu o shell (ou recebeu); nada a fazer
		}
		return texto.toString("UTF-8");
	}

	// ------------------------------------------------------------ preparar a TV
	/**
	 * Os comandos do PREPARAR_TV.bat numa linha de shell da TV: a tela inicial
	 * do jogo ligada e escolhida (e o papel HOME no Android 10+), "Sobrepor"
	 * permitido, fora da economia de energia, sem descanso de tela e sem
	 * desligar por inatividade. As telas da TV (telas) só saem se a tela
	 * inicial do jogo aparecer entre as telas iniciais (sem nenhuma, a TV não
	 * abriria nada), só as instaladas, e ficam anotadas em "anotar" (para o
	 * PREPARAR_TV.bat -DevolverTv). Escreve TV_PRONTA ou SEM_TELA_DO_JOGO.
	 */
	/**
	 * Os comandos que deixam a TV Box SÓ DO JOGO (rodam no adb da própria TV,
	 * como o PREPARAR_TV.bat do Dragon Bowling):
	 *  - a tela inicial do jogo (ligada aqui, desligada no APK) escolhida -
	 *    e as telas da TV Box desligadas (só depois de conferir a do jogo);
	 *  - "Sobrepor a outros apps" e "acender a tela" permitidos, o jogo fora
	 *    da economia de bateria;
	 *  - câmera e notificações permitidas (nenhuma janela de permissão);
	 *  - o serviço do Arduino ligado (aperta OK na janela do USB a cada vez
	 *    que liga e marca o "Sempre" onde a janela tem);
	 *  - sem descanso de tela e sem desligar sozinha.
	 * No fim escreve TV_PRONTA (ou SEM_TELA_DO_JOGO: nada foi desligado).
	 */
	static String comandoPreparar(String pacote, String atividade, String servico, List<String> telas, String anotar) {
		StringBuilder l = new StringBuilder();
		for (String p : telas) {
			if (p.matches("[A-Za-z0-9_.]+")) {
				l.append(p).append(' ');
			}
		}
		return "P=" + pacote + "; A=" + pacote + "/" + atividade + "; S=" + pacote + "/" + servico + "; L='" + l.toString().trim() + "'; "
				+ "pm enable $A >/dev/null 2>&1; cmd package set-home-activity $A >/dev/null 2>&1 || pm set-home-activity $A >/dev/null 2>&1; "
				+ "if [ \"$(getprop ro.build.version.sdk)\" -ge 29 ]; then cmd role add-role-holder android.app.role.HOME $P >/dev/null 2>&1; fi; "
				+ "appops set $P SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1; appops set $P TURN_SCREEN_ON allow >/dev/null 2>&1; "
				+ "dumpsys deviceidle whitelist +$P >/dev/null 2>&1; "
				+ "pm grant $P android.permission.CAMERA >/dev/null 2>&1; pm grant $P android.permission.POST_NOTIFICATIONS >/dev/null 2>&1; "
				+ "E=$(settings get secure enabled_accessibility_services); "
				+ "case \"$E\" in *$S*) ;; null|'') settings put secure enabled_accessibility_services $S ;; *) settings put secure enabled_accessibility_services \"$E:$S\" ;; esac; "
				+ "settings put secure accessibility_enabled 1; "
				+ "settings put secure screensaver_enabled 0; settings put secure screensaver_activate_on_sleep 0; "
				+ "settings put secure screensaver_activate_on_dock 0; settings put secure sleep_timeout -1; "
				+ "settings put secure attentive_timeout -1; settings put system screen_off_timeout 2147483647; "
				+ "if (cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null; "
				+ "pm query-activities -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null) | grep -q StrikeInicioAtivo; then "
				+ "for X in $L; do if pm list packages | grep -q \"^package:$X$\"; then "
				+ "pm disable-user --user 0 $X >/dev/null 2>&1 && echo $X >> " + anotar + "; fi; done; echo TV_PRONTA; "
				+ "else echo SEM_TELA_DO_JOGO; fi";
	}

	// ------------------------------------------------------------ base64
	private static final char[] B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toCharArray();

	static String base64(byte[] d) {
		StringBuilder sb = new StringBuilder((d.length + 2) / 3 * 4);
		for (int i = 0; i < d.length; i += 3) {
			int a = d[i] & 0xff;
			int b = i + 1 < d.length ? d[i + 1] & 0xff : 0;
			int c = i + 2 < d.length ? d[i + 2] & 0xff : 0;
			int v = (a << 16) | (b << 8) | c;
			sb.append(B64[(v >> 18) & 63]).append(B64[(v >> 12) & 63]);
			sb.append(i + 1 < d.length ? B64[(v >> 6) & 63] : '=');
			sb.append(i + 2 < d.length ? B64[v & 63] : '=');
		}
		return sb.toString();
	}
}
