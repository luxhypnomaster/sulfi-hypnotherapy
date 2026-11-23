"""Read-only driver regressions; no Google identity or emulator result claims."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import native25 as n
from candidate25 import GateError

XML='<hierarchy><node text="fresh" class="android.widget.TextView" /></hierarchy>'


class SnapshotTest(unittest.TestCase):
    def observe(self, outputs, state='device', stale=False):
        context=tempfile.TemporaryDirectory();self.addCleanup(context.cleanup)
        out=Path(context.name);actions=[];calls=[];turn=[-1]
        if stale:(out/'latest-window.xml').write_text('<hierarchy><node text="STALE" /></hierarchy>')
        def run(args,**kw):
            turn[0]+=1;calls.append(args)
            return subprocess.CompletedProcess(args,0 if outputs[turn[0]].startswith('<hierarchy>') else 1,'','could not get idle state' if not outputs[turn[0]] else '')
        def adb(*args,**kw):
            calls.append(args)
            if args[0]=='get-state':return state
            if args[0]=='exec-out':return outputs[turn[0]]
            return ''
        with mock.patch.object(n.time,'sleep'):
            result=n.accessibility_snapshot(adb,out,actions,run)
        return result,actions,calls

    def test_transient_idle_failure_recovers_with_only_fresh_read(self):
        nodes,actions,calls=self.observe(['',XML],stale=True)
        self.assertEqual(nodes[0].get('text'),'fresh')
        self.assertEqual(actions[0]['attempts'],2)
        self.assertFalse(actions[0]['repeatedUIActions'])
        self.assertFalse(any('tap' in c or 'keyevent' in c or 'install' in c for c in calls))
        self.assertEqual(sum(c[0]=='shell' and c[1]=='rm' for c in calls if isinstance(c,tuple)),2)

    def test_stale_last_xml_is_never_used_when_three_fresh_reads_fail(self):
        with self.assertRaisesRegex(GateError,'AFTER_3_FRESH_READS'):
            self.observe(['','',''],stale=True)

    def test_disconnected_emulator_stops_before_retry(self):
        with self.assertRaisesRegex(GateError,'EMULATOR_CONNECTION_LOST_NO_RETRY'):
            self.observe([''],state='offline')

    def test_malformed_transition_tree_is_not_accepted(self):
        nodes,actions,_=self.observe(['<hierarchy><node',XML])
        self.assertEqual(nodes[0].get('text'),'fresh')
        self.assertEqual(actions[0]['failures'][0]['error'],'ParseError')


class ReaderTest(unittest.TestCase):
    def fake_ui(self, master):
        class UI:
            def __init__(self):self.reader=not master;self.open=False;self.calls=[]
            def home(self):self.calls.append('home')
            def label(self,node):return node['label']
            def tree(self):
                if self.open:return [{'label':'Controlled offline text'}]
                if master and not self.reader:return [{'label':'Автор'},{'label':'Читатель'}]
                return [{'label':'QA25 cached public diary'}]
            def click(self,text,**kw):
                self.calls.append(text)
                if text=='Читатель':self.reader=True
                if text=='QA25 cached public diary':
                    if not self.reader:raise AssertionError('MASTER_AUTHOR_LIST_IS_NOT_PUBLIC_FEED')
                    self.open=True
            def shot(self,name):self.calls.append(name)
        return UI()

    def test_master_switches_existing_reader_view_before_public_entry(self):
        ui=self.fake_ui(True);result=n.open_public_cache(ui)
        self.assertTrue(result['cachePreservedAndReadableOffline'])
        self.assertEqual(ui.calls[:4],['home','Дневник','Читатель','QA25 cached public diary'])
        self.assertEqual(result['Google'],'NOT_RUN')

    def test_client_does_not_receive_an_author_mode_or_role(self):
        ui=self.fake_ui(False);n.open_public_cache(ui)
        self.assertNotIn('Читатель',ui.calls)
        self.assertNotIn('Автор',ui.calls)


if __name__=='__main__':unittest.main(verbosity=2)
