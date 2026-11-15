package org.alchemist.p0probe;

import android.database.sqlite.SQLiteDatabase;
import android.os.Build;
import android.os.Process;
import org.json.JSONObject;
import org.json.JSONArray;
import java.io.File;
import java.lang.reflect.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Runs shipped sqflite pool classes from the disposable APK, never owner DBs. */
public final class NativePoolProbe {
  public static void main(String[] args) throws Exception {
    if (args.length != 2 || !args[0].equals("ru.sulfi.sulfi_hypnotherapy.transferprobe")
        || !(Build.HARDWARE.contains("ranchu") || Build.HARDWARE.contains("goldfish"))
        || Process.myUid() < 10000) throw new SecurityException("DISPOSABLE_APP_UID_REQUIRED");
    int count = Integer.parseInt(args[1]);
    if (count != 1 && count != 4) throw new SecurityException("UNREVIEWED_POOL_SIZE");
    File root = new File("/data/user/0/" + args[0] + "/files");
    if (!root.isDirectory()) throw new SecurityException("EXISTING_DISPOSABLE_FILES_REQUIRED");
    File fixture = File.createTempFile("native-sqlite-lock18-", ".sqlite", root);
    SQLiteDatabase a = SQLiteDatabase.openOrCreateDatabase(fixture, null);
    a.execSQL("CREATE TABLE fixture(id INTEGER PRIMARY KEY, value TEXT)");
    SQLiteDatabase b = SQLiteDatabase.openOrCreateDatabase(fixture, null);
    List<String> events = Collections.synchronizedList(new ArrayList<>());
    List<String> errors = Collections.synchronizedList(new ArrayList<>());
    Class<?> poolType = Class.forName("com.tekartik.sqflite.DatabaseWorkerPool");
    Class<?> delegate = Class.forName("com.tekartik.sqflite.DatabaseDelegate");
    Class<?> task = Class.forName("com.tekartik.sqflite.DatabaseTask");
    Object pool = poolType.getMethod("create", String.class, int.class, int.class)
        .invoke(null, "NativePoolProbe18", count, 0);
    poolType.getMethod("start").invoke(pool);
    Constructor<?> constructor = task.getDeclaredConstructor(delegate, Runnable.class);
    constructor.setAccessible(true);
    Method post = poolType.getMethod("post", task);
    AtomicBoolean inA = new AtomicBoolean();
    Object da = Proxy.newProxyInstance(delegate.getClassLoader(), new Class<?>[]{delegate}, (proxy,m,v) ->
        m.getName().equals("getDatabaseId") ? Integer.valueOf(1) : Boolean.valueOf(inA.get()));
    Object db = Proxy.newProxyInstance(delegate.getClassLoader(), new Class<?>[]{delegate}, (proxy,m,v) ->
        m.getName().equals("getDatabaseId") ? Integer.valueOf(2) : Boolean.FALSE);
    CountDownLatch entered = new CountDownLatch(1), completed = new CountDownLatch(2);
    post.invoke(pool, constructor.newInstance(da, (Runnable)() -> {
      try { a.beginTransaction(); inA.set(true); a.execSQL("INSERT INTO fixture VALUES(1,'writer-a')");
        events.add("A_WRITE_TRANSACTION_OPEN");
      } catch (Throwable e) { errors.add(e.getClass().getSimpleName()); }
      finally { entered.countDown(); }
    }));
    if (!entered.await(10, TimeUnit.SECONDS) || !errors.isEmpty()) throw new AssertionError("NO_FIRST_TRANSACTION");
    post.invoke(pool, constructor.newInstance(db, (Runnable)() -> {
      try { events.add("B_WRITE_STARTED"); b.execSQL("INSERT INTO fixture VALUES(2,'writer-b')"); events.add("B_COMMITTED"); }
      catch (Throwable e) { errors.add(e.getClass().getSimpleName()); }
      finally { completed.countDown(); }
    }));
    Thread.sleep(250); // B's lock wait precedes A's COMMIT in the actual native pool.
    events.add("A_COMMIT_ENQUEUED");
    post.invoke(pool, constructor.newInstance(da, (Runnable)() -> {
      try { a.setTransactionSuccessful(); a.endTransaction(); inA.set(false); events.add("A_COMMITTED"); }
      catch (Throwable e) { errors.add(e.getClass().getSimpleName()); }
      finally { completed.countDown(); }
    }));
    boolean finished = completed.await(15, TimeUnit.SECONDS);
    String integrity = "NOT_RUN_BLOCKED";
    int rows = -1;
    if (finished && errors.isEmpty()) {
      try (android.database.Cursor c = a.rawQuery("SELECT count(*) FROM fixture", null)) { c.moveToFirst(); rows = c.getInt(0); }
      try (android.database.Cursor c = a.rawQuery("PRAGMA integrity_check", null)) { c.moveToFirst(); integrity = c.getString(0); }
      b.close(); a.close(); poolType.getMethod("quit").invoke(pool);
      if (!fixture.delete()) throw new AssertionError("FIXTURE_CLEANUP_FAILED");
    }
    JSONObject result = new JSONObject().put("classification", "ACTUAL_APK_NATIVE_SQFLITE_POOL_ANDROID_SQLITE")
        .put("pool", count).put("status", finished && errors.isEmpty() ? "BOTH_COMMITS_COMPLETE" : "BLOCKED_NATIVE_POOL_LOCK_ORDER")
        .put("events", new JSONArray(events)).put("errors", new JSONArray(errors)).put("rows", rows).put("integrity", integrity)
        .put("productionDatabaseOpened", false).put("Google", "NOT_RUN");
    System.out.println("NATIVE_POOL18=" + result.toString());
    System.out.flush();
    System.exit(0); // Ends only this disposable app_process, not an owner's app.
  }
}
