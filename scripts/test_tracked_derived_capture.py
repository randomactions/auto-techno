"""Tracked transaction mechanics; fixtures are not native or quality evidence."""
import copy,hashlib,json,os,shutil,subprocess,tempfile,unittest
from pathlib import Path
import baseline_capture_transaction as capture
import baseline_dependency_contract as dependency
import test_baseline_capture_transaction as fixtures

class TrackedDerivedCaptureTests(unittest.TestCase):
 def setUp(self):
  self.base=fixtures.CaptureTransactionTests();self.base.setUp();self.addCleanup(self.base.doCleanups)
  self.root=self.base.root;self.context=self.base.context;self.info=self.base.info;self.family='deficit-register'
  self.paths=sorted(capture.TRACKED_OUTPUTS[self.family]);self.old={self.paths[0]:json.dumps({'schema':'autotechno-deficit-register.v1','registerVersion':1,'fixture':'original'}),self.paths[1]:'Original tracked rendering\n'}
  for name,text in self.old.items():self.base.fixture.write(name,text)
  self.base.fixture.capture();self.parents={};nodes={n['id']:n for n in dependency.lifecycle.NODES};required=set()
  def visit(name):
   for parent in nodes[name]['dependencies']:
    if parent not in required:required.add(parent);visit(parent)
  visit(self.family)
  for name in dependency.lifecycle.topological_order(dependency.lifecycle.NODES):
   if name not in required:continue
   node=nodes[name];paths=[node['artifactPath']];document={'schema':node['schema'],node['versionField']:node['version']}
   if name in ('whole-mix-render','role-stem-capture'):
    wave='docs/local/audio/'+name+'.wav';paths.append(wave)
    document['entries']=[{'wavPath':wave}] if name=='whole-mix-render' else [{'files':[{'wavPath':wave}]}]
   def produce(paths=paths,document=document):
    for path in paths:self.base.fixture.write(path,json.dumps(document) if path.endswith('.json') else 'Fixture waveform bytes')
    return 0
   ancestors=set()
   def ancestors_of(name):
    for parent in nodes[name]['dependencies']:
     if parent not in ancestors:ancestors.add(parent);ancestors_of(parent)
   ancestors_of(name)
   self.parents[name]=capture.record_fresh_capture(self.root,name,self.context,paths,self.info,self.info,produce,lambda:0,upstream_bindings=[self.parents[p] for p in ancestors])
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.candidate=Path(tmp.name)/'candidate'
  subprocess.run(['git','clone','--shared','--quiet',str(self.root),str(self.candidate)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  shutil.copytree(self.root/'docs/local',self.candidate/'docs/local')
  self.calls=[]
 def write(self,name,text):
  path=self.candidate/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
 def produce(self):
  self.calls.append('producer');self.write(self.paths[0],json.dumps({'schema':'autotechno-deficit-register.v1','registerVersion':1,'fixture':'new candidate'}));self.write(self.paths[1],'Fresh independently checked rendering\n');return 0
 def validate(self):
  self.calls.append('validator');self.assertEqual(json.loads((self.candidate/self.paths[0]).read_text())['fixture'],'new candidate');self.assertEqual((self.candidate/self.paths[1]).read_text(),'Fresh independently checked rendering\n');return 0
 def bind(self,producer=None,validator=None,paths=None,candidate=None):
  return capture.record_fresh_capture(self.root,self.family,self.context,paths or self.paths,self.info,self.info,producer or self.produce,validator or self.validate,upstream_bindings=list(self.parents.values()),candidate_root=candidate or self.candidate)
 def unchanged(self):
  self.assertEqual({n:(self.root/n).read_text() for n in self.paths},self.old)
  self.assertEqual(dependency.git(self.root,'status','--porcelain'),b'')
 def reseal(self,value):value['bindingFingerprint']=dependency.digest({k:v for k,v in value.items() if k!='bindingFingerprint'})
 def test_candidate_changes_only_derived_outputs_and_keeps_origin_exact(self):
  before=dependency.capture(self.root,self.context);value=self.bind();self.assertEqual(self.calls,['producer','validator']);self.unchanged()
  self.assertEqual(value['originSnapshot'],before);self.assertEqual(value['schema'],capture.TRACKED_SCHEMA)
  capture.validate_binding(value,self.candidate,bindings=self.parents)
  with self.assertRaisesRegex(capture.CaptureTransactionError,'hash/size'):capture.validate_binding(value,self.root,bindings=self.parents)
  self.assertTrue(all(flag is False for flag in value['qualification'].values()))
 def test_explicit_candidate_required_before_actions(self):
  with self.assertRaisesRegex(capture.CaptureTransactionError,'isolated candidate'):
   capture.record_fresh_capture(self.root,self.family,self.context,self.paths,self.info,self.info,self.produce,self.validate,upstream_bindings=list(self.parents.values()))
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_same_root_and_omitted_markdown_refuse_before_actions(self):
  with self.assertRaisesRegex(capture.CaptureTransactionError,'separate'):self.bind(candidate=self.root)
  with self.assertRaisesRegex(capture.CaptureTransactionError,'exact registered'):self.bind(paths=[self.paths[0]])
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_candidate_output_hardlink_refuses_before_original_can_be_mutated(self):
  path=self.candidate/self.paths[0];path.unlink();os.link(self.root/self.paths[0],path)
  with self.assertRaisesRegex(capture.CaptureTransactionError,'alias original'):self.bind()
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_extra_tracked_path_and_local_capture_candidate_refuse(self):
  with self.assertRaisesRegex(capture.CaptureTransactionError,'exact registered'):self.bind(paths=self.paths+['docs/SOUND_QUALITY.md'])
  with self.assertRaisesRegex(capture.CaptureTransactionError,'local capture'):
   capture.record_fresh_capture(self.root,'whole-mix-render',self.context,self.base.paths,self.info,self.info,self.produce,self.validate,candidate_root=self.candidate)
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_candidate_preexisting_input_drift_refuses_before_actions(self):
  self.write('Sources/Owner.swift','unexpected input')
  with self.assertRaises(dependency.DependencyContractError):self.bind()
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_ignored_private_corpus_cannot_drift_inside_tracked_projection(self):
  name='docs/local/private-corpus.json';self.write(name,'{"private":"frozen"}')
  context=dict(self.context,captureCorpusPath=name,captureCorpusSha256=hashlib.sha256((self.candidate/name).read_bytes()).hexdigest())
  before=dependency.capture(self.candidate,context);self.write(name,'{"private":"changed"}')
  with self.assertRaisesRegex(capture.CaptureTransactionError,'private corpus changed'):capture.require_frozen_inputs(self.candidate,before,set(self.paths))
  self.unchanged()
 def test_candidate_producer_input_change_refuses_and_preserves_failure(self):
  def producer():self.produce();self.write('Sources/Owner.swift','mutated input');return 0
  with self.assertRaisesRegex(capture.CaptureTransactionError,'undeclared input'):self.bind(producer=producer)
  self.assertTrue((self.candidate/self.paths[0]).exists());self.unchanged()
 def test_candidate_index_change_refuses(self):
  def validator():self.validate();subprocess.run(['git','add',self.paths[0]],cwd=self.candidate,check=True);return 0
  with self.assertRaisesRegex(capture.CaptureTransactionError,'index changed'):self.bind(validator=validator)
  self.unchanged()
 def test_candidate_head_change_refuses(self):
  def validator():
   self.validate();subprocess.run(['git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','--allow-empty','-qm','Changed head'],cwd=self.candidate,check=True);return 0
  with self.assertRaisesRegex(capture.CaptureTransactionError,'HEAD changed'):self.bind(validator=validator)
  self.unchanged()
 def test_candidate_validator_output_mutation_refuses(self):
  def validator():self.validate();self.write(self.paths[1],'Changed during validation');return 0
  with self.assertRaisesRegex(capture.CaptureTransactionError,'changed capture bytes'):self.bind(validator=validator)
  self.unchanged()
 def test_failed_candidate_validator_preserves_candidate_and_originals(self):
  with self.assertRaisesRegex(capture.CaptureTransactionError,'validator'):self.bind(validator=lambda:1)
  self.assertIn('new candidate',(self.candidate/self.paths[0]).read_text());self.unchanged()
 def test_failed_producer_cannot_backfill_success(self):
  with self.assertRaisesRegex(capture.CaptureTransactionError,'producer'):self.bind(producer=lambda:False)
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_candidate_upstream_corruption_refuses_before_actions(self):
  parent=next(v for v in self.parents.values() if v['familyId']=='whole-mix-render');self.write(parent['outputs'][0]['path'],'Corrupt upstream')
  with self.assertRaises(capture.CaptureTransactionError):self.bind()
  self.assertEqual(self.calls,[]);self.unchanged()
 def test_resealed_original_output_record_cannot_retag_git_bytes(self):
  value=self.bind();value['sourceOutputInputs'][0]['sha256']='f'*64;self.reseal(value)
  with self.assertRaisesRegex(capture.CaptureTransactionError,'original Git bytes'):capture.validate_binding(value,self.candidate,bindings=self.parents)
  self.unchanged()
 def test_resealed_output_coverage_and_false_integer_claim_refuse(self):
  value=self.bind();changed=copy.deepcopy(value);changed['outputs'].pop();self.reseal(changed)
  with self.assertRaises(capture.CaptureTransactionError):capture.validate_binding(changed,self.candidate,bindings=self.parents)
  changed=copy.deepcopy(value);changed['qualification']['promotionAuthorized']=0;self.reseal(changed)
  with self.assertRaisesRegex(capture.CaptureTransactionError,'qualification'):capture.validate_binding(changed,self.candidate,bindings=self.parents)
  self.unchanged()
 def test_symlink_output_refuses_without_touching_original(self):
  path=self.candidate/self.paths[0];path.unlink();path.symlink_to(self.root/self.paths[0])
  with self.assertRaises(dependency.DependencyContractError):self.bind()
  self.assertEqual({n:(self.root/n).read_text() for n in self.paths},self.old)
 def test_publication_occurs_only_after_validated_candidate(self):
  value=self.bind();self.unchanged();calls=[]
  def validator():calls.append('published-validator');self.assertEqual((self.root/self.paths[0]).read_bytes(),(self.candidate/self.paths[0]).read_bytes());return 0
  capture.publish_tracked_capture(value,self.root,self.candidate,validator,bindings=self.parents)
  self.assertEqual(calls,['published-validator']);capture.validate_binding(value,self.root,bindings=self.parents)
  self.assertEqual(dependency.git(self.root,'rev-parse','HEAD').decode().strip(),value['originSnapshot']['gitHead'])
 def test_failed_publication_restores_original_and_keeps_candidate(self):
  value=self.bind()
  with self.assertRaisesRegex(capture.CaptureTransactionError,'validator'):capture.publish_tracked_capture(value,self.root,self.candidate,lambda:1,bindings=self.parents)
  self.unchanged();capture.validate_binding(value,self.candidate,bindings=self.parents)
 def test_publication_source_drift_refuses_before_output_installation(self):
  value=self.bind();self.base.fixture.write('Sources/Owner.swift','Source drift')
  with self.assertRaises(dependency.DependencyContractError):capture.publish_tracked_capture(value,self.root,self.candidate,lambda:0,bindings=self.parents)
  self.assertEqual({n:(self.root/n).read_text() for n in self.paths},self.old)
 def test_publication_candidate_drift_refuses_before_output_installation(self):
  value=self.bind();self.write(self.paths[0],'Candidate corruption')
  with self.assertRaises(capture.CaptureTransactionError):capture.publish_tracked_capture(value,self.root,self.candidate,lambda:0,bindings=self.parents)
  self.unchanged()
 def test_mutating_published_validator_rolls_back_registered_outputs(self):
  value=self.bind()
  def validator():self.base.fixture.write(self.paths[1],'Illegal mutation');return 0
  with self.assertRaises(capture.CaptureTransactionError):capture.publish_tracked_capture(value,self.root,self.candidate,validator,bindings=self.parents)
  self.unchanged()
 def test_published_leaf_symlink_is_rejected_and_original_slot_restored(self):
  value=self.bind();source_before=(self.root/'Sources/Owner.swift').read_bytes()
  def validator():
   path=self.root/self.paths[1];path.unlink();path.symlink_to(self.root/'Sources/Owner.swift');return 0
  with self.assertRaises(capture.CaptureTransactionError):capture.publish_tracked_capture(value,self.root,self.candidate,validator,bindings=self.parents)
  self.unchanged();self.assertEqual((self.root/'Sources/Owner.swift').read_bytes(),source_before)

if __name__=='__main__':unittest.main()
