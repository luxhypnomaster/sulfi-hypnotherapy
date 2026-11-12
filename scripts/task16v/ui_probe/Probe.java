package org.alchemist.p0probe;

import android.app.Instrumentation;
import android.os.Bundle;
import android.view.accessibility.AccessibilityNodeInfo;
import android.graphics.Rect;
import android.util.Base64;
import android.util.Xml;
import org.xmlpull.v1.XmlSerializer;
import java.io.StringWriter;
import java.util.ArrayList;
import java.io.File;
import java.io.FileInputStream;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.security.MessageDigest;
import android.database.sqlite.SQLiteDatabase;
import android.database.DatabaseErrorHandler;
import org.json.JSONObject;

/** Disposable test runner only. Reads/acts on Android UI; no DB, network or role APIs. */
public class Probe extends Instrumentation {
  private Bundle args;
  @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); args=arguments; start(); }
  private void write(XmlSerializer x, AccessibilityNodeInfo n, int depth) throws Exception {
    if(n==null||depth>60)return;
    x.startTag(null,"node");
    String[][] attrs={{"text",String.valueOf(n.getText()==null?"":n.getText())},
      {"content-desc",String.valueOf(n.getContentDescription()==null?"":n.getContentDescription())},
      {"class",String.valueOf(n.getClassName())},{"resource-id",String.valueOf(n.getViewIdResourceName())},
      {"enabled",String.valueOf(n.isEnabled())},{"clickable",String.valueOf(n.isClickable())}};
    for(String[] a:attrs)x.attribute(null,a[0],a[1]);
    Rect r=new Rect();n.getBoundsInScreen(r);
    x.attribute(null,"bounds","["+r.left+","+r.top+"]["+r.right+","+r.bottom+"]");
    for(int i=0;i<n.getChildCount();i++)write(x,n.getChild(i),depth+1);
    x.endTag(null,"node");
  }
  private void fields(AccessibilityNodeInfo n, ArrayList<AccessibilityNodeInfo> all) {
    if(n==null)return;
    if(n.isEditable())all.add(n);
    for(int i=0;i<n.getChildCount();i++)fields(n.getChild(i),all);
  }
  private String hash(File f) throws Exception {
    if(!f.exists())return "MISSING";
    MessageDigest d=MessageDigest.getInstance("SHA-256");
    try(FileInputStream in=new FileInputStream(f)){byte[] b=new byte[8192];for(int n;(n=in.read(b))>0;)d.update(b,0,n);}
    StringBuilder s=new StringBuilder();for(byte b:d.digest())s.append(String.format("%02x",b));return s.toString();
  }
  private JSONObject corruptionProbe() throws Exception {
    File dir=getTargetContext().getFilesDir();
    File source=new File(dir,"controlled-source.sqlite");
    SQLiteDatabase db=SQLiteDatabase.openOrCreateDatabase(source,null);
    db.execSQL("CREATE TABLE sentinel (id TEXT)");db.execSQL("INSERT INTO sentinel VALUES ('CONTROLLED_HELPER_ONLY')");db.close();
    JSONObject result=new JSONObject();
    for(String name:new String[]{"default_rw","guard_readonly"}){
      File file=new File(dir,name+".sqlite");Files.copy(source.toPath(),file.toPath());
      try(RandomAccessFile f=new RandomAccessFile(file,"rw")){f.seek(0);f.write("NOT_SQLITE_TEST!!".getBytes("UTF-8"));f.getFD().sync();}
      String before=hash(file);String error="none";
      try {
        SQLiteDatabase opened=name.equals("default_rw")
          ? SQLiteDatabase.openDatabase(file.getPath(),null,SQLiteDatabase.CREATE_IF_NECESSARY)
          : SQLiteDatabase.openDatabase(file.getPath(),null,SQLiteDatabase.OPEN_READONLY,new DatabaseErrorHandler(){public void onCorruption(SQLiteDatabase ignored){}});
        opened.rawQuery("PRAGMA integrity_check",null).close();opened.close();
      }catch(Exception e){error=e.getClass().getSimpleName();}
      JSONObject row=new JSONObject();row.put("before_sha256",before);row.put("after_sha256",hash(file));row.put("exists",file.exists());row.put("exception",error);row.put("bytesUnchanged",before.equals(hash(file)));result.put(name,row);
    }
    result.put("kind","DISPOSABLE_HELPER_DB_ONLY_NOT_SULFI_OR_OWNER");return result;
  }
  @Override public void onStart() {
    Bundle result=new Bundle();
    try {
      if("corruption".equals(args.getString("op"))){result.putString("dependency_probe",corruptionProbe().toString());finish(-1,result);return;}
      getUiAutomation();Thread.sleep(300);
      AccessibilityNodeInfo root=null;
      for(int i=0;i<15&&root==null;i++){root=getUiAutomation().getRootInActiveWindow();if(root==null)Thread.sleep(200);}
      if(root==null)throw new IllegalStateException("NO_ACTIVE_UI_ROOT");
      if("text".equals(args.getString("op"))){
        ArrayList<AccessibilityNodeInfo> all=new ArrayList<>();fields(root,all);
        int index=Integer.parseInt(args.getString("index","0"));
        String text=new String(Base64.decode(args.getString("value"),Base64.DEFAULT),"UTF-8");
        Bundle b=new Bundle();b.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,text);
        if(index>=all.size()||!all.get(index).performAction(AccessibilityNodeInfo.ACTION_SET_TEXT,b))throw new IllegalStateException("UI_SET_TEXT_REJECTED");
        result.putString("changed","true");
      }else{
        StringWriter s=new StringWriter();XmlSerializer xml=Xml.newSerializer();xml.setOutput(s);
        xml.startTag(null,"hierarchy");write(xml,root,0);xml.endTag(null,"hierarchy");xml.flush();
        result.putString("payload",Base64.encodeToString(s.toString().getBytes("UTF-8"),Base64.NO_WRAP));
      }
      finish(-1,result);
    }catch(Exception error){result.putString("failure",error.getClass().getSimpleName()+":"+error.getMessage());finish(0,result);}
  }
}
