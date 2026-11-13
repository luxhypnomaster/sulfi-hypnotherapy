package org.alchemist.storageprobe;

import android.app.Instrumentation;
import android.os.Bundle;
import android.database.sqlite.SQLiteDatabase;
import com.tekartik.sqflite.StorageSafety;
import java.io.File;
import java.io.FileInputStream;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.security.MessageDigest;
import org.json.JSONObject;

/** Runs exact vendored production callback, only on helper-owned disposable DBs. */
public class GuardProbe extends Instrumentation {
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    private String hash(File file) throws Exception {
        if (!file.exists()) return "ABSENT";
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream stream = new FileInputStream(file)) {
            byte[] bytes = new byte[8192];
            for (int count; (count = stream.read(bytes)) > 0;) digest.update(bytes, 0, count);
        }
        StringBuilder hex = new StringBuilder();
        for (byte value : digest.digest()) hex.append(String.format("%02x", value));
        return hex.toString();
    }
    private JSONObject snapshot(File file) throws Exception {
        JSONObject value = new JSONObject();
        for (String suffix : new String[]{"", "-wal", "-shm", "-journal"})
            value.put(suffix, hash(new File(file.getPath() + suffix)));
        return value;
    }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            File root = getTargetContext().getFilesDir();
            File healthy = new File(root, "healthy.sqlite");
            SQLiteDatabase db = StorageSafety.open(healthy.getPath(), SQLiteDatabase.CREATE_IF_NECESSARY);
            db.execSQL("CREATE TABLE sentinel(id TEXT)");
            db.execSQL("INSERT INTO sentinel VALUES('CONTROLLED_ONLY')");
            db.close();
            db = StorageSafety.open(healthy.getPath(), SQLiteDatabase.OPEN_READWRITE);
            try (android.database.Cursor c = db.rawQuery("SELECT id FROM sentinel", null)) {
                if (!c.moveToFirst() || !"CONTROLLED_ONLY".equals(c.getString(0))) throw new AssertionError("HEALTHY_ROWS");
            }
            db.close();
            JSONObject proof = new JSONObject();
            proof.put("healthyCreateAndReopen", "PASS");
            for (String mode : new String[]{"guard_rw", "guard_ro"}) {
                File file = new File(root, mode + ".sqlite");
                Files.copy(healthy.toPath(), file.toPath());
                try (RandomAccessFile damaged = new RandomAccessFile(file, "rw")) {
                    damaged.seek(0); damaged.write("NOT_SQLITE_TEST!!".getBytes("UTF-8")); damaged.getFD().sync();
                }
                JSONObject before = snapshot(file);
                String exception = "NONE";
                try {
                    SQLiteDatabase opened = StorageSafety.open(file.getPath(), mode.equals("guard_rw")
                        ? SQLiteDatabase.CREATE_IF_NECESSARY : SQLiteDatabase.OPEN_READONLY);
                    try { opened.rawQuery("PRAGMA integrity_check", null).close(); } finally { opened.close(); }
                } catch (android.database.sqlite.SQLiteDatabaseCorruptException e) {
                    exception = e.getClass().getSimpleName();
                }
                JSONObject after = snapshot(file);
                boolean unchanged = before.toString().equals(after.toString());
                proof.put(mode, new JSONObject().put("before", before).put("after", after)
                    .put("exception", exception).put("originalBytesUnchanged", unchanged));
                if (!unchanged || "NONE".equals(exception)) throw new AssertionError("UNSAFE_" + mode);
            }
            proof.put("productionSource", "third_party/sqflite_android/.../StorageSafety.java");
            proof.put("ownerData", "NONE");
            result.putString("STORAGE_16G", proof.toString());
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("STORAGE_16G_FAILURE", error.getClass().getSimpleName() + ":" + error.getMessage());
            finish(1, result);
        }
    }
}
