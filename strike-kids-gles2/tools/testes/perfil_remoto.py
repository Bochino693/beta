# -*- coding: utf-8 -*-
"""
PERFIL DE SCRIPTS QUADRO A QUADRO (só no PC): faz o papel do editor do
Godot 3 no "remote debug" e liga o medidor de funções. O jogo manda, a cada
quadro, quanto cada função de script levou — aqui saem as funções que mais
pesam no total e, para os quadros mais lentos (os trancos), quem pesou
naquele quadro.

    python3 tools/testes/perfil_remoto.py [porta] [segundos] &
    godot3 --path . --remote-debug 127.0.0.1:6007 --fixed-fps 60 -- --janela=270x480 --desempenho --perfil-seg=120

(o jogo conecta na porta; quando ele fecha, sai o relatório)
"""
import socket
import struct
import sys
from collections import defaultdict

PORTA = int(sys.argv[1]) if len(sys.argv) > 1 else 6007


class Leitor:
    def __init__(self, sock):
        self.s = sock
        self.buf = b""

    def _ler(self, n):
        while len(self.buf) < n:
            d = self.s.recv(65536)
            if not d:
                raise EOFError
            self.buf += d
        r, self.buf = self.buf[:n], self.buf[n:]
        return r

    def pacote(self):
        (n,) = struct.unpack("<I", self._ler(4))
        return self._ler(n)


def decodificar(b, pos=0):
    """Variant do Godot 3 (core/io/marshalls.cpp) -> (valor, nova posição)."""
    (cab,) = struct.unpack_from("<I", b, pos)
    pos += 4
    tipo = cab & 0xFFFF
    f64 = cab & (1 << 16)
    if tipo == 0:
        return None, pos
    if tipo == 1:
        (v,) = struct.unpack_from("<i", b, pos)
        return bool(v), pos + 4
    if tipo == 2:
        if f64:
            (v,) = struct.unpack_from("<q", b, pos)
            return v, pos + 8
        (v,) = struct.unpack_from("<i", b, pos)
        return v, pos + 4
    if tipo == 3:
        if f64:
            (v,) = struct.unpack_from("<d", b, pos)
            return v, pos + 8
        (v,) = struct.unpack_from("<f", b, pos)
        return v, pos + 4
    if tipo == 4:
        (n,) = struct.unpack_from("<I", b, pos)
        pos += 4
        s = b[pos:pos + n].decode("utf-8", "replace")
        pos += n
        pos += (4 - n % 4) % 4
        return s, pos
    tamanhos = {5: 8, 6: 16, 7: 12, 8: 24, 9: 16, 10: 16, 11: 24, 12: 36, 13: 48, 14: 16}
    if tipo in tamanhos:
        return ("<%d>" % tipo), pos + tamanhos[tipo]
    if tipo == 15:   # NodePath
        (n,) = struct.unpack_from("<I", b, pos)
        pos += 4
        if n & 0x80000000:
            n &= 0x7FFFFFFF
            (sub,) = struct.unpack_from("<I", b, pos)
            pos += 8   # subnames + flags
            for _ in range(n + sub):
                (k,) = struct.unpack_from("<I", b, pos)
                pos += 4 + k + (4 - k % 4) % 4
        else:
            pos += n + (4 - n % 4) % 4
        return "<nodepath>", pos
    if tipo == 16:
        return "<rid>", pos + 8
    if tipo == 17:   # objeto: como id (ENCODE_FLAG_OBJECT_AS_ID) ou nulo
        if f64:
            return "<obj>", pos + 8
        (n,) = struct.unpack_from("<I", b, pos)
        return "<obj>", pos + 4 + n + (4 - n % 4) % 4 if n else pos + 4
    if tipo == 18:
        (n,) = struct.unpack_from("<I", b, pos)
        pos += 4
        d = {}
        for _ in range(n & 0x7FFFFFFF):
            k, pos = decodificar(b, pos)
            v, pos = decodificar(b, pos)
            d[str(k)] = v
        return d, pos
    if tipo == 19:
        (n,) = struct.unpack_from("<I", b, pos)
        pos += 4
        a = []
        for _ in range(n & 0x7FFFFFFF):
            v, pos = decodificar(b, pos)
            a.append(v)
        return a, pos
    if tipo in (20, 21, 22, 23, 24, 25, 26):
        (n,) = struct.unpack_from("<I", b, pos)
        pos += 4
        if tipo == 20:
            return "<bytes>", pos + n + (4 - n % 4) % 4
        if tipo == 23:
            for _ in range(n):
                (k,) = struct.unpack_from("<I", b, pos)
                pos += 4 + k + (4 - k % 4) % 4
            return "<strings>", pos
        por = {21: 4, 22: 4, 24: 8, 25: 12, 26: 16}[tipo]
        return "<pool>", pos + n * por
    raise ValueError("tipo %d" % tipo)


def codificar(v):
    if isinstance(v, str):
        d = v.encode("utf-8")
        return struct.pack("<II", 4, len(d)) + d + b"\0" * ((4 - len(d) % 4) % 4)
    if isinstance(v, bool):
        return struct.pack("<Ii", 1, int(v))
    if isinstance(v, int):
        return struct.pack("<Ii", 2, v)
    if isinstance(v, list):
        r = struct.pack("<II", 19, len(v))
        for x in v:
            r += codificar(x)
        return r
    raise ValueError(v)


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", PORTA))
    srv.listen(1)
    print("esperando o jogo na porta", PORTA, flush=True)
    con, _ = srv.accept()
    print("jogo conectou", flush=True)
    pac = codificar(["start_profiling", 200])
    con.sendall(struct.pack("<I", len(pac)) + pac)
    le = Leitor(con)
    nomes = {}
    quadros = []
    try:
        while True:
            cmd, _ = decodificar(le.pacote())
            if not isinstance(cmd, str):
                continue
            n, _ = decodificar(le.pacote())
            dados = [decodificar(le.pacote())[0] for _ in range(n)]
            if cmd == "profile_sig":
                nomes[dados[1]] = dados[0]
            elif cmd == "profile_frame":
                quadro, t_quadro, t_idle, t_fis, t_fis_q, t_script, n_dados, n_func = dados[:8]
                i = 8 + n_dados * 2
                funcs = []
                for _ in range(n_func):
                    sig, chamadas, total, proprio = dados[i:i + 4]
                    i += 4
                    funcs.append((sig, chamadas, total, proprio))
                quadros.append((quadro, t_quadro, t_idle, t_fis, t_script, funcs))
    except (EOFError, ConnectionResetError):
        pass
    print("quadros recebidos:", len(quadros))
    if not quadros:
        return
    # funções que mais pesam no total
    soma = defaultdict(float)
    tot = defaultdict(float)
    cham = defaultdict(int)
    maior = defaultdict(float)
    for q in quadros:
        for sig, c, t, p in q[5]:
            soma[sig] += p
            tot[sig] += t
            cham[sig] += c
            maior[sig] = max(maior[sig], p)
    nq = len(quadros)
    print("\nFUNÇÕES (média por quadro, us): próprio | total | pior quadro (próprio) | chamadas")
    for sig in sorted(soma, key=lambda k: -soma[k])[:40]:
        print("%8.1f %8.1f %9.1f %8.1f  %s" % (1e6 * soma[sig] / nq, 1e6 * tot[sig] / nq, 1e6 * maior[sig],
                                                cham[sig] / nq, nomes.get(sig, sig).replace("res://", "")))
    # os quadros com mais script
    print("\nQUADROS COM MAIS SCRIPT (ms):")
    for q in sorted(quadros, key=lambda q: -q[4])[:25]:
        top = sorted(q[5], key=lambda f: -f[3])[:5]
        txt = "; ".join("%s %.1f" % (nomes.get(f[0], f[0]).split("::")[-1], 1000 * f[3]) for f in top)
        print("quadro %6d script %6.2f idle %6.2f fis %6.2f | %s" % (q[0], 1000 * q[4], 1000 * q[2], 1000 * q[3], txt))


if __name__ == "__main__":
    main()
