import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Enumeration;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/**
 * Faz o modelo Android do Strike Kids: o android_release.apk oficial do
 * Godot 3.6.3 com os extras de android/modelo_android/extras.zip (manifesto
 * com os plugins da camera e do Arduino, recursos remontados, classes2.dex).
 * Do oficial vem tudo, menos os recursos (res/, resources.arsc, o manifesto)
 * e o que os extras trazem. Cada arquivo guarda o jeito de compressao de
 * origem (o Godot respeita o do modelo; o resources.arsc fica sem
 * compressao, como o Android 11+ exige).
 *
 *   java -jar tools/android/remendo_apk.jar oficial.apk extras.zip saida.apk
 *
 * Feito com: javac --release 8 RemendoApk.java (tools/android/remendo/construir.sh)
 */
public class RemendoApk {
    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            System.err.println("uso: java -jar remendo_apk.jar <android_release.apk oficial> <extras.zip> <saida.apk>");
            System.exit(2);
        }
        File saida = new File(args[2]);
        File parcial = new File(args[2] + ".parcial");
        Set<String> extras = new LinkedHashSet<String>();
        ZipFile ex = new ZipFile(args[1]);
        ZipFile of = new ZipFile(args[0]);
        int doOficial = 0;
        int dosExtras = 0;
        try {
            for (Enumeration<? extends ZipEntry> e = ex.entries(); e.hasMoreElements();) {
                extras.add(e.nextElement().getName());
            }
            if (!extras.contains("AndroidManifest.xml") || !extras.contains("resources.arsc")) {
                throw new IOException("extras.zip sem o manifesto ou sem o resources.arsc");
            }
            ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(parcial), 1 << 20));
            try {
                byte[] buf = new byte[1 << 16];
                for (Enumeration<? extends ZipEntry> e = of.entries(); e.hasMoreElements();) {
                    ZipEntry z = e.nextElement();
                    String n = z.getName();
                    if (n.startsWith("res/") || n.equals("resources.arsc") || n.equals("AndroidManifest.xml") || extras.contains(n)) {
                        continue;
                    }
                    copiar(of, z, out, buf);
                    doOficial++;
                }
                for (Enumeration<? extends ZipEntry> e = ex.entries(); e.hasMoreElements();) {
                    copiar(ex, e.nextElement(), out, buf);
                    dosExtras++;
                }
            } finally {
                out.close();
            }
        } finally {
            of.close();
            ex.close();
        }
        if (doOficial < 10) {
            throw new IOException("o modelo oficial parece vazio (" + doOficial + " arquivos)");
        }
        if (saida.exists() && !saida.delete()) {
            throw new IOException("nao consegui substituir " + saida);
        }
        if (!parcial.renameTo(saida)) {
            throw new IOException("nao consegui gravar " + saida);
        }
        System.out.println("modelo do Strike Kids pronto: " + doOficial + " arquivos do oficial + " + dosExtras + " extras -> " + saida);
    }

    private static void copiar(ZipFile de, ZipEntry z, ZipOutputStream out, byte[] buf) throws IOException {
        ZipEntry novo = new ZipEntry(z.getName());
        novo.setTime(z.getTime());
        if (z.getMethod() == ZipEntry.STORED) {
            novo.setMethod(ZipEntry.STORED);
            novo.setSize(z.getSize());
            novo.setCompressedSize(z.getSize());
            novo.setCrc(z.getCrc());
        } else {
            novo.setMethod(ZipEntry.DEFLATED);
        }
        out.putNextEntry(novo);
        if (!z.isDirectory()) {
            InputStream in = de.getInputStream(z);
            try {
                int k;
                while ((k = in.read(buf)) > 0) {
                    out.write(buf, 0, k);
                }
            } finally {
                in.close();
            }
        }
        out.closeEntry();
    }
}
