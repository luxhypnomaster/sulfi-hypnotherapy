import ast,pathlib,unittest,xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[2]
class Navigation(unittest.TestCase):
 def test_actual_launcher_windows_and_app_negative(self):
  tree=ast.parse((ROOT/'scripts/task17/native_upgrade.py').read_text());f=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='is_android_launcher')
  namespace={};exec(compile(ast.Module(body=[f],type_ignores=[]),'isolated-navigation','exec'),namespace);check=namespace[f.name]
  for name,case in [('master25','ui_import_3'),('master26','ui_module_pause')]:
   nodes=list(ET.parse(ROOT/f'reports/task17/native_api34_attempt1/{name}/screens/failure-{case}.xml').iter('node'));self.assertTrue(check(nodes))
  self.assertFalse(check([ET.Element('node',{'resource-id':'ru.sulfi.sulfi_hypnotherapy:id/content','text':'Google search'})]))
  self.assertFalse(check([ET.Element('node',{'resource-id':'com.google.android.apps.nexuslauncher:id/launcher'}),ET.Element('node',{'text':"Pixel Launcher isn't responding"})]))
 def test_actual_journal_cannot_be_editor(self):
  tree=ast.parse((ROOT/'scripts/task17/native_upgrade.py').read_text());nodes=[x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name in ['label','diary_editor_ready']]
  ns={};exec(compile(ast.Module(body=nodes,type_ignores=[]),'isolated-route','exec'),ns)
  journal=list(ET.parse(ROOT/'reports/task17/process_probe/screens/failure-local_draft_after27.xml').iter('node'))
  self.assertFalse(ns['diary_editor_ready'](journal))
  editor=[ET.Element('node',{'text':'РЕДАКТОР ЗАПИСИ'}),ET.Element('node',{'text':'Сохранить черновик'}),ET.Element('node',{'class':'android.widget.EditText'}),ET.Element('node',{'class':'android.widget.EditText'})]
  self.assertTrue(ns['diary_editor_ready'](editor))
if __name__=='__main__':unittest.main()
