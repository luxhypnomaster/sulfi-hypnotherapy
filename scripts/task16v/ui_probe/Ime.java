package org.alchemist.p0ime;

import android.inputmethodservice.InputMethodService;
import android.view.View;
import android.widget.TextView;

/** Test-only IME in a separate process; never distributed to real users. */
public class Ime extends InputMethodService {
  static Ime active;
  @Override public void onCreate(){super.onCreate();active=this;}
  @Override public void onDestroy(){active=null;super.onDestroy();}
  @Override public View onCreateInputView(){TextView v=new TextView(this);v.setText("Disposable native UI test input");v.setHeight(48);return v;}
}
