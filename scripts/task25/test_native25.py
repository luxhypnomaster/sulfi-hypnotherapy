"""Read-only driver regressions; no Google identity or emulator result claims."""
from pathlib import Path
import ast
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


class PhysicalProfileTest(unittest.TestCase):
    def test_profile_reduces_only_render_frame_and_preserves_partition(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'config.ini'
            p.write_text('hw.lcd.width=1080\nhw.lcd.height=1920\nhw.lcd.density=420\ndisk.dataPartition.size=3G\nuntouched=value\n')
            result=n.configure_display(p)
            self.assertEqual(result['before']['hw.lcd.width'],'1080')
            self.assertEqual(result['after'],{'hw.lcd.width':'720','hw.lcd.height':'1280','hw.lcd.density':'280'})
            self.assertIn('disk.dataPartition.size=3G',p.read_text())
            self.assertIn('untouched=value',p.read_text())
            self.assertFalse(result['applicationOrDatabaseChanged'])

    def test_unknown_partition_or_symlink_refused_before_write(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'config.ini';p.write_text('disk.dataPartition.size=100G\n')
            with self.assertRaises(GateError):n.configure_display(p)
            self.assertEqual(p.read_text(),'disk.dataPartition.size=100G\n')
            link=Path(td)/'link.ini';link.symlink_to(p)
            with self.assertRaises(GateError):n.configure_display(link)


class MasterEditorTest(unittest.TestCase):
    def ui(self, state):
        class UI:
            def __init__(self):self.state=state;self.calls=[]
            def label(self,node):return node
            def tree(self):
                return {'reader':['К списку записей','Controlled offline text'],
                        'public':['Автор','Читатель'],
                        'author':['Автор','Читатель','Новая запись'],
                        'local_public':['Мои записи','Читатель'],
                        'client':['Controlled offline text']}[self.state]
            def click(self,label,exact=False):
                self.calls.append(label)
                if label=='К списку записей' and self.state=='reader':self.state='public'
                elif label=='Автор' and self.state=='public':self.state='author'
                elif label=='Мои записи' and self.state=='local_public':self.state='author'
                else:raise AssertionError('INVALID_UI_TRANSITION')
        return UI()

    def test_actual_reader_failure_requires_return_to_list_and_author_before_editor(self):
        failure=Path(__file__).resolve().parents[2]/'reports/task25/candidate29/native_attempt5/failure-ui_master_local_diary29.xml'
        self.assertIn('К списку записей',failure.read_text())
        ui=self.ui('reader')
        def original():self.assertIn('Новая запись',ui.tree());ui.calls.append('original_ready_and_persistence_checks')
        n.open_master_editor(ui,original)
        self.assertEqual(ui.calls,['К списку записей','Автор','original_ready_and_persistence_checks'])

    def test_already_author_has_no_extra_navigation(self):
        ui=self.ui('author');n.open_master_editor(ui,lambda:ui.calls.append('original'))
        self.assertEqual(ui.calls,['original'])

    def test_existing_local_notes_mode_is_an_observed_view_not_a_new_role(self):
        ui=self.ui('local_public')
        n.open_master_editor(ui,lambda:self.assertIn('Новая запись',ui.tree()))
        self.assertEqual(ui.calls,['Мои записи'])

    def test_missing_author_does_not_invent_a_role_or_success(self):
        ui=self.ui('client')
        def original():raise GateError('ORIGINAL_EDITOR_NOT_READY')
        with self.assertRaisesRegex(GateError,'ORIGINAL_EDITOR_NOT_READY'):n.open_master_editor(ui,original)
        self.assertEqual(ui.calls,[])

    def test_all_original_p0_assertions_and_cases_are_structurally_identical(self):
        old=ast.parse(subprocess.check_output(['git','show','f7c82b4:scripts/task25/native25.py'],text=True))
        new=ast.parse(Path(n.__file__).read_text())
        new.body=[x for x in new.body if (not isinstance(x,ast.FunctionDef) or x.name!='open_master_editor')
                  and (not isinstance(x,ast.Import) or ast.unparse(x)!='import emulator_sdk25 as sdk25')]
        prepare=next(x for x in new.body if isinstance(x,ast.FunctionDef) and x.name=='prepare_profile')
        setup=next(x for x in prepare.body if isinstance(x,ast.Assign) and ast.unparse(x.targets[0])=='sdk_receipt')
        self.assertEqual(ast.unparse(setup.value),'sdk25.install()');prepare.body.remove(setup)
        ready=next(x for x in prepare.body if isinstance(x,ast.Expr) and ast.unparse(x.value)=='sdk25.record_ready(sdk_receipt)')
        prepare.body.remove(ready)
        main=next(x for x in new.body if isinstance(x,ast.FunctionDef) and x.name=='main')
        readiness=next(x for x in main.body if isinstance(x,ast.If) and ast.unparse(x.test)=='not sdk25.ready_valid(ready)')
        oldmain=next(x for x in old.body if isinstance(x,ast.FunctionDef) and x.name=='main')
        oldready=next(x for x in oldmain.body if isinstance(x,ast.If) and any(isinstance(a,ast.Constant) and a.value=='PINNED_EMULATOR_PREHOOK_NOT_CONFIRMED' for a in ast.walk(x)))
        self.assertEqual(ast.dump(ast.Module(body=readiness.body,type_ignores=[])),ast.dump(ast.Module(body=oldready.body,type_ignores=[])))
        readiness.test=oldready.test
        report=next(x for x in main.body if isinstance(x,ast.FunctionDef) and x.name=='report')
        payload=report.body[0].value.args[1]
        for name,value in [('emulatorVersion','sdk25.VERSION'),('emulatorArchiveSHA256','sdk25.SHA256')]:
            i=next(i for i,k in enumerate(payload.keys) if isinstance(k,ast.Constant) and k.value==name)
            self.assertEqual(ast.unparse(payload.values[i]),value);payload.keys.pop(i);payload.values.pop(i)
        binding=next(x for x in main.body if isinstance(x,ast.If) and ast.unparse(x.test)=="args.edition == 'master'")
        self.assertEqual(ast.unparse(binding.body[0]),'original_editor = m.open_diary_editor')
        self.assertEqual(ast.unparse(binding.body[1]),'m.open_diary_editor = lambda: open_master_editor(m, original_editor)')
        main.body.remove(binding)
        api_option=next(x for x in main.body if isinstance(x,ast.Expr)
                        and isinstance(x.value,ast.Call) and any(isinstance(a,ast.Constant) and a.value=='--api' for a in x.value.args))
        choice=next(k for k in api_option.value.keywords if k.arg=='choices')
        self.assertEqual(ast.literal_eval(choice.value),[34,35,36])
        choice.value=ast.List(elts=[ast.Constant(value=34),ast.Constant(value=36)],ctx=ast.Load())
        self.assertEqual(ast.dump(old),ast.dump(new))


if __name__=='__main__':unittest.main(verbosity=2)
