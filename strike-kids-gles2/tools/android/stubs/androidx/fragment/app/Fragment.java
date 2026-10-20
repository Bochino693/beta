package androidx.fragment.app;

/**
 * SÓ PARA COMPILAR os plugins: no Godot 3.6.3 a classe
 * org.godotengine.godot.Godot é um Fragment do androidx, e o javac precisa
 * enxergar essa classe-mãe. O androidx de verdade só existe no repositório do
 * Google (fora do nosso alcance), então fica este esqueleto vazio. Ele NÃO
 * vai para o .aar nem para o APK: no aparelho vale o Fragment de verdade, que
 * já está no classes.dex do Godot (os plugins nem chamam nada dele).
 */
public class Fragment {
}
