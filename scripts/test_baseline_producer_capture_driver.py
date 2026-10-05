"""Controls for namespace-only parity normalization and immutable local receipts."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parent))
import baseline_producer_capture_driver as driver
import baseline_producer_witness as producer


class ProducerCaptureDriverTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.documents=[]
        for namespace in ['v1','reference']:
            name='docs/local/audio/baseline-corpus-'+namespace+'/identity.wav'
            path=self.root/name
            path.parent.mkdir(parents=True)
            path.write_bytes(b'whole fixture bytes')
            self.documents.append({'schema':'fixture','gitHead':'original','entries':[
                {'id':'identity','wavPath':name,'pcmSha256':'fixed','stateFingerprint':'actual-state','sampleRate':48000}]})

    def test_namespace_only_descriptor_difference_allows_exact_bytes(self):
        self.assertEqual(driver.exact_bank_parity(self.root,*self.documents,'whole-mix-render'),1)

    def test_pcm_bytes_change_refuses_even_with_resealed_equal_manifest(self):
        (self.root/self.documents[1]['entries'][0]['wavPath']).write_bytes(b'different PCM bytes')
        with self.assertRaisesRegex(producer.ProducerWitnessError,'WAV bytes'):
            driver.exact_bank_parity(self.root,*self.documents,'whole-mix-render')

    def test_state_route_and_origin_metadata_are_not_normalized_away(self):
        for location,key,value in [('entry','stateFingerprint','different'),('entry','sampleRate',44100),('root','gitHead','retagged')]:
            altered=copy.deepcopy(self.documents[1])
            (altered['entries'][0] if location=='entry' else altered)[key]=value
            with self.assertRaisesRegex(producer.ProducerWitnessError,'typed evidence'):
                driver.exact_bank_parity(self.root,self.documents[0],altered,'whole-mix-render')

    def test_role_normalization_retains_reconstruction_and_pcm_evidence(self):
        first={'wholeMixManifestSha256':'original-whole-path-hash','entries':[
            {'id':'identity','reconstruction':{'maximumError':0},'files':[
                {'signal':'kick','wavPath':'docs/local/first.wav','pcmSha256':'unchanged','channelCount':1}]}]}
        second=copy.deepcopy(first)
        second['wholeMixManifestSha256']='other-whole-descriptor-hash'
        second['entries'][0]['files'][0]['wavPath']='docs/local/second.wav'
        self.assertEqual(driver.normalized_manifest(first,'role-stem-capture'),driver.normalized_manifest(second,'role-stem-capture'))
        second['entries'][0]['reconstruction']['maximumError']=0.1
        self.assertNotEqual(driver.normalized_manifest(first,'role-stem-capture'),driver.normalized_manifest(second,'role-stem-capture'))
        self.assertIn('wavPath',first['entries'][0]['files'][0])

    def test_duplicate_asset_id_is_rejected(self):
        document=copy.deepcopy(self.documents[0])
        document['entries'].append(copy.deepcopy(document['entries'][0]))
        with self.assertRaisesRegex(producer.ProducerWitnessError,'duplicate'):
            driver.wave_index(document,'whole-mix-render')

    def test_existing_receipt_is_not_overwritten(self):
        path='docs/local/reports/fresh.json'
        driver.fresh_json(self.root,path,{'original':True})
        with self.assertRaises(FileExistsError): driver.fresh_json(self.root,path,{'retagged':True})
        self.assertEqual(json.loads((self.root/path).read_text()),{'original':True})

    def test_native_argument_layout_is_registered_exactly(self):
        argv=['helper','--filter',producer.PROBE_FILTER,'--testing-library','swift-testing']
        changed=driver.select_filter(argv,'BaselineRenderIntegrationTests')
        self.assertEqual(changed[2],'BaselineRenderIntegrationTests')
        self.assertEqual(argv[2],producer.PROBE_FILTER)
        for bad in [['helper'],['helper','--filter','arbitrary'],argv+['--filter','duplicate']]:
            with self.assertRaises(producer.ProducerWitnessError): driver.select_filter(bad,'producer')


if __name__=='__main__':unittest.main()
