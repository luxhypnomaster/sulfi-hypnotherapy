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
  @Override public void onStart() {
    Bundle result=new Bundle();
    try {
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
