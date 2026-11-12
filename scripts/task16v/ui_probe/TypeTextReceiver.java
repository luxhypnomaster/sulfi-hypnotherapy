package org.alchemist.p0ime;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Base64;
import android.view.inputmethod.InputConnection;

public class TypeTextReceiver extends BroadcastReceiver {
  @Override public void onReceive(Context context,Intent intent){
    InputConnection c=Ime.active==null?null:Ime.active.getCurrentInputConnection();
    if(c==null){setResultData("NO_INPUT_CONNECTION");return;}
    try {
      String text=new String(Base64.decode(intent.getStringExtra("value"),Base64.DEFAULT),"UTF-8");
      c.beginBatchEdit();c.performContextMenuAction(android.R.id.selectAll);
      boolean ok=c.commitText(text,1);c.endBatchEdit();setResultData(ok?"UI_TEXT_COMMITTED":"UI_TEXT_REJECTED");
    }catch(Exception error){setResultData(error.getClass().getSimpleName());}
  }
}
