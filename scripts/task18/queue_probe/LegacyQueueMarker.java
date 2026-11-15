package org.alchemist.p0probe;

import android.content.ContentValues;
import android.database.Cursor;
import android.database.DatabaseErrorHandler;
import android.database.sqlite.SQLiteDatabase;
import android.os.Build;
import android.os.Process;
import android.system.Os;
import java.io.File;
import java.nio.file.Files;
import java.security.MessageDigest;
import org.json.JSONArray;
import org.json.JSONObject;

/** ONLY disposable emulator fixture rows; no auth, network, schema or file replacement. */
public final class LegacyQueueMarker {
  private static void require(boolean ok, String code) {
    if (!ok) throw new IllegalStateException(code);
  }
  private static String hash(String s) throws Exception {
    byte[] h = MessageDigest.getInstance("SHA-256").digest(s.getBytes("UTF-8"));
    StringBuilder b = new StringBuilder();
    for (byte v : h) b.append(String.format("%02x", v & 255));
    return b.toString();
  }
  public static void main(String[] args) throws Exception {
    require(args.length == 3, "EXPLICIT_OP_PACKAGE_INPUT_REQUIRED");
    String op = args[0], pkg = args[1];
    require(op.equals("seed") || op.equals("verify"), "NO_OTHER_OPERATIONS");
    require(pkg.equals("ru.sulfi.sulfi_hypnotherapy") || pkg.equals("ru.sulfi.sulfi_hypnotherapy.clienttest"), "WRONG_PACKAGE");
    require(Build.HARDWARE.equals("ranchu") || Build.HARDWARE.equals("goldfish"), "EMULATOR_HARDWARE_REQUIRED");
    File root = new File("/data/user/0/" + pkg + "/files");
    File dbFile = new File(root, "library.sqlite");
    require(dbFile.isFile() && Os.stat(dbFile.getPath()).st_uid == Process.myUid() && Process.myUid() >= 10000, "EXISTING_APP_UID_DB_REQUIRED");
    File input = new File(args[2]);
    require(input.getCanonicalFile().getParentFile().equals(root.getCanonicalFile()), "PRIVATE_FIXTURE_INPUT_REQUIRED");
    JSONObject fixture = new JSONObject(new String(Files.readAllBytes(input.toPath()), "UTF-8"));
    require(fixture.getString("classification").equals("CONTROLLED_NATIVE_OLD27_QUEUE_NOT_GOOGLE"), "NO_REAL_OWNER_DATA");
    JSONArray rows = fixture.getJSONArray("rows");
    require(rows.length() == 5, "EXACT_FIVE_CONTROLLED_ROWS_REQUIRED");
    for (int i=0; i<rows.length(); i++) {
      String key = rows.getJSONObject(i).getString("name");
      require(key.matches("alchemist_(card|upload):controlled_native18_legacy_[a-z]+"), "CONTROLLED_KEY_REQUIRED");
      require(rows.getJSONObject(i).getString("value").contains("CONTROLLED_NATIVE_OLD27"), "CONTROLLED_PAYLOAD_REQUIRED");
    }
    DatabaseErrorHandler noReset = db -> { throw new IllegalStateException("NO_RESET_ON_CORRUPTION"); };
    SQLiteDatabase db = SQLiteDatabase.openDatabase(dbFile.getPath(), null,
        op.equals("seed") ? SQLiteDatabase.OPEN_READWRITE : SQLiteDatabase.OPEN_READONLY, noReset);
    try {
      require(db.getVersion() == 9, "IMMUTABLE27_SCHEMA9_REQUIRED");
      if (op.equals("seed")) {
        db.beginTransaction();
        try {
          for (int i=0; i<rows.length(); i++) {
            JSONObject row=rows.getJSONObject(i);ContentValues v=new ContentValues();
            v.put("name",row.getString("name"));v.put("value",row.getString("value"));
            db.insertOrThrow("app_settings",null,v); // collision STOP; never replace
          }
          db.setTransactionSuccessful();
        } finally { db.endTransaction(); }
      }
      JSONArray digests = new JSONArray();
      for (int i=0; i<rows.length(); i++) {
        JSONObject row=rows.getJSONObject(i);
        try(Cursor c=db.query("app_settings",new String[]{"value"},"name=?",new String[]{row.getString("name")},null,null,null)) {
          require(c.moveToFirst() && c.getString(0).equals(row.getString("value")), "LEGACY_QUEUE_BYTES_CHANGED");
          digests.put(new JSONObject().put("name",row.getString("name")).put("sha256",hash(c.getString(0))));
          require(!c.moveToNext(), "DUPLICATE_KEY");
        }
      }
      try(Cursor c=db.rawQuery("PRAGMA integrity_check",null)) { require(c.moveToFirst() && c.getString(0).equals("ok"),"INTEGRITY_FAILED"); }
      System.out.println(new JSONObject().put("status","PASS").put("operation",op)
          .put("schema",db.getVersion()).put("integrity","ok").put("fixtureRowDigests",digests)
          .put("Google","NOT_RUN").put("classification","CONTROLLED_NATIVE_OLD27_QUEUE_NOT_GOOGLE").toString());
    } finally { db.close(); }
  }
}
