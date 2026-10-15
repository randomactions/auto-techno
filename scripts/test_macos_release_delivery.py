"""Synthetic byte-delivery controls; never native app, resource, route or quality QA."""
from contextlib import redirect_stdout
import copy
import gzip
import io
import json
import os
from pathlib import Path
import struct
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import macos_release_delivery as delivery

SOURCE = '1' * 40
TREE = '2' * 40
REPO = 'randomactions/auto-techno'


class ReleaseDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root, self.binary, self.out = self.base/'source', self.base/'build/release', self.base/'delivery'
        self.binary.mkdir(parents=True)
        resources = self.root/'Sources/AutoTechnoDSP/Resources'
        resources.mkdir(parents=True)
        (resources/'profile.json').write_bytes(b'{"fixture":"not-qualified"}\n')
        (self.binary/'AutoTechno').write_bytes(struct.pack('<IiiIIIII',0xfeedfacf,0x100000c,0,2,0,0,0,0)+b'fixture-not-an-app')
        (self.binary/'AutoTechno').chmod(0o755)
        (self.binary/delivery.BUNDLE_NAME).mkdir()
        (self.binary/delivery.BUNDLE_NAME/'profile.json').write_bytes((resources/'profile.json').read_bytes())
        self.env = dict(GITHUB_ACTIONS='true', GITHUB_SHA=SOURCE, GITHUB_REPOSITORY=REPO,
                        GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='2', RUNNER_TEMP=str(self.base))
        self.job = dict(id=456, run_id=123, run_attempt=2, head_sha=SOURCE,
            name='hosted-macos / Complete macOS bank 0',status='completed',conclusion='success',
            url=f'https://api.github.com/repos/{REPO}/actions/jobs/456',
            html_url=f'https://github.com/{REPO}/actions/runs/123/job/456', steps=[])
        for index,name in enumerate(('Build all native tests','Execute complete native bank','Run complete tooling tests',
                'Build macOS Release app','Validate codebase map','Package macOS Release validation artifact',
                'Upload macOS Release validation artifact'),1):
            self.job['steps'].append(dict(name=name,status='completed',conclusion='success',number=index))

    def git(self, root, *args):
        if args == ('rev-parse','HEAD'):return SOURCE
        if args == ('rev-parse','HEAD^{tree}'):return TREE
        if args == ('status','--porcelain','--untracked-files=all'):return ''
        if args == ('ls-files','--','Sources/AutoTechnoDSP/Resources'):return 'Sources/AutoTechnoDSP/Resources/profile.json'
        raise AssertionError(args)

    def pack(self):
        output=io.StringIO()
        with patch.object(delivery.platform,'system',return_value='Darwin'), \
             patch.object(delivery.platform,'machine',return_value='arm64'), \
             patch.object(delivery.platform,'mac_ver',return_value=('15.0',(),'')), \
             patch.object(delivery,'git',side_effect=self.git), \
             patch.object(delivery.subprocess,'check_output',return_value='Swift fixture compiler'), redirect_stdout(output):
            delivery.pack(self.root,self.binary,self.out,self.env)
        self.record=delivery.strict_json((self.out/'delivery.json').read_bytes())
        self.log=output.getvalue().encode()
        self.archive=self.out/delivery.ARCHIVE_NAME

    def verify(self, extract=None, record=None, log=None, job=None):
        return delivery.verify_delivery(self.archive,self.record if record is None else record,SOURCE,REPO,123,2,
            self.log if log is None else log,self.job if job is None else job,extract)

    def rewrite_archive(self, raw):
        self.archive.write_bytes(gzip.compress(raw,mtime=0))
        self.record['archiveBytes']=self.archive.stat().st_size
        self.record['archiveSHA256']=delivery.sha(self.archive)
        self.log=delivery.PREFIX.encode()+delivery.canonical(self.record)+b'\n'

    def tar_rows(self, rows):
        data=io.BytesIO()
        with tarfile.open(fileobj=data,mode='w',format=tarfile.USTAR_FORMAT) as tar:
            for info,raw in rows:tar.addfile(info,io.BytesIO(raw) if info.isfile() else None)
        return data.getvalue()

    def original_rows(self):
        rows=[]
        with tarfile.open(self.archive,'r:gz') as tar:
            for info in tar:
                rows.append((copy.copy(info),tar.extractfile(info).read()))
        return rows

    def test_exact_delivery_extraction_preserves_bytes_and_explicit_false_authority(self):
        self.pack();target=self.base/'local-qa'
        result=self.verify(target)
        self.assertEqual((target/'AutoTechno').read_bytes(),(self.binary/'AutoTechno').read_bytes())
        self.assertEqual((target/delivery.BUNDLE_NAME/'profile.json').read_bytes(),(self.binary/delivery.BUNDLE_NAME/'profile.json').read_bytes())
        self.assertTrue(result['deliveryBytesVerified'])
        self.assertTrue(result['originalJobDeliveryVerified'])
        self.assertEqual(result['claims'],{name:False for name in delivery.CLAIMS})
        if os.name!='nt':self.assertEqual((target/'AutoTechno').stat().st_mode & 0o777,0o755)

    def test_original_actions_timestamp_is_accepted(self):
        self.pack();self.verify(log=b'2026-10-15T12:00:00.123Z '+self.log)

    def test_missing_duplicate_or_echoed_receipt_refuses(self):
        self.pack()
        for raw in [b'no receipt',self.log+self.log,b"print('"+self.log.rstrip()+b"')\n"]:
            with self.subTest(raw=raw[:25]),self.assertRaises(ValueError):self.verify(log=raw)

    def test_all_source_run_repository_and_artifact_substitutions_refuse(self):
        self.pack()
        for key,value in [('source','3'*40),('sourceTree',123),('repository','other/repo'),('runId',124),
                ('runAttempt',1),('runAttempt',True),('schema','other'),('subject','AT-0040'),
                ('artifactName','other'),('buildConfiguration','debug'),('scope','passed'),('archive','other.tar.gz')]:
            record=copy.deepcopy(self.record);record[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):self.verify(record=record)

    def test_claims_are_boolean_false_and_cannot_be_promoted(self):
        self.pack()
        for key in delivery.CLAIMS:
            for value in [True,0,'false',None]:
                record=copy.deepcopy(self.record);record['claims'][key]=value
                with self.subTest(key=key,value=value),self.assertRaises(ValueError):self.verify(record=record)

    def test_original_job_binding_and_every_successful_delivery_step_required(self):
        self.pack()
        changes=[('status','in_progress'),('conclusion','failure'),('head_sha','3'*40),('run_id',124),
            ('run_attempt',1),('name','Native map and component (default)'),('url','https://example.com'),
            ('html_url','https://example.com'),('id',True)]
        for key,value in changes:
            job=copy.deepcopy(self.job);job[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):self.verify(job=job)
        for index in range(len(self.job['steps'])):
            for result in ['failure','skipped']:
                job=copy.deepcopy(self.job);job['steps'][index]['conclusion']=result
                with self.subTest(index=index,result=result),self.assertRaises(ValueError):self.verify(job=job)
        job=copy.deepcopy(self.job);job['steps'][-1]['number']=1
        with self.assertRaises(ValueError):self.verify(job=job)
        job=copy.deepcopy(self.job);job['steps'].append(job['steps'][0].copy())
        with self.assertRaises(ValueError):self.verify(job=job)

    def test_payload_and_original_log_must_agree_on_all_bytes(self):
        self.pack();record=copy.deepcopy(self.record);record['archiveSHA256']='0'*64
        with self.assertRaises(ValueError):self.verify(record=record)
        self.archive.write_bytes(self.archive.read_bytes()+b'alteration')
        with self.assertRaises(ValueError):self.verify()

    def test_complete_unique_inventory_and_safe_owned_paths_required(self):
        self.pack()
        for path in ['/escape','../escape',delivery.ROOT_NAME+'/../escape',delivery.ROOT_NAME+'//AutoTechno',
                delivery.ROOT_NAME+'/AutoTechno\\escape',delivery.ROOT_NAME+'/foreign/file']:
            record=copy.deepcopy(self.record);record['files'][0]['path']=path
            with self.subTest(path=path),self.assertRaises(ValueError):self.verify(record=record)
        for mutate in [lambda r:r['files'].append(r['files'][0].copy()),lambda r:r.update(files=r['files'][:1]),
                lambda r:r['files'][0].update(bytes=0),lambda r:r['files'][0].update(bytes=delivery.MAX_BYTES+1),
                lambda r:r['files'][0].update(mode=0o777),lambda r:r['files'][0].update(bytes=True)]:
            record=copy.deepcopy(self.record);mutate(record)
            with self.assertRaises(ValueError):self.verify(record=record)

    def test_tar_member_removal_duplication_unknown_and_links_refuse_before_extraction(self):
        self.pack();original=self.original_rows()
        changes=[]
        changes.append(original[:-1]);changes.append(original+[original[0]])
        extra=tarfile.TarInfo(delivery.ROOT_NAME+'/'+delivery.BUNDLE_NAME+'/foreign');extra.size=1
        changes.append(original+[(extra,b'x')])
        for kind in [tarfile.SYMTYPE,tarfile.LNKTYPE,tarfile.DIRTYPE,tarfile.XHDTYPE]:
            info=copy.copy(original[0][0]);info.type=kind;info.linkname='../outside' if kind in [tarfile.SYMTYPE,tarfile.LNKTYPE] else '';info.size=0
            changes.append([(info,b'')]+original[1:])
        for index,rows in enumerate(changes):
            self.rewrite_archive(self.tar_rows(rows));target=self.base/f'unsafe-{index}'
            with self.subTest(index=index),self.assertRaises((ValueError,tarfile.TarError)):
                self.verify(target)
            self.assertFalse(target.exists())

    def test_tar_modes_hashes_architecture_and_padding_are_recomputed(self):
        self.pack();original=self.original_rows()
        for label in ['mode','hash','architecture','padding','terminator','trailing']:
            rows=copy.deepcopy(original)
            if label=='mode':rows[0][0].mode=0o644
            if label=='hash':rows[0]=(rows[0][0],rows[0][1][:-1]+b'x')
            if label=='architecture':rows[0]=(rows[0][0],b'bad!'+rows[0][1][4:])
            raw=bytearray(self.tar_rows(rows))
            if label=='padding':raw[512+rows[0][0].size]=1
            if label=='terminator':raw=raw[:sum(512+((i.size+511)//512)*512 for i,_ in rows)+512]
            if label=='trailing':raw+=b'x'
            self.rewrite_archive(bytes(raw))
            with self.subTest(label=label),self.assertRaises(ValueError):self.verify()

    def test_extraction_never_overwrites_an_existing_directory(self):
        self.pack();target=self.base/'existing';target.mkdir();(target/'keep').write_bytes(b'keep')
        with self.assertRaises(ValueError):self.verify(target)
        self.assertEqual((target/'keep').read_bytes(),b'keep')

    def test_source_resource_byte_changes_and_unknown_files_refuse(self):
        resource=self.binary/delivery.BUNDLE_NAME/'profile.json';resource.write_bytes(b'changed')
        with patch.object(delivery,'git',side_effect=self.git),self.assertRaises(ValueError):delivery.inventory(self.root,self.binary)
        resource.write_bytes((self.root/'Sources/AutoTechnoDSP/Resources/profile.json').read_bytes())
        (self.binary/delivery.BUNDLE_NAME/'private.wav').write_bytes(b'not PCM')
        with patch.object(delivery,'git',side_effect=self.git),self.assertRaises(ValueError):delivery.inventory(self.root,self.binary)

    def test_runtime_tree_inventory_stops_at_fixed_file_and_directory_limits(self):
        for index in range(delivery.MAX_FILES):
            (self.binary/delivery.BUNDLE_NAME/f'extra-{index}.json').write_bytes(b'{}')
        with patch.object(delivery,'git',side_effect=self.git),self.assertRaises(ValueError):delivery.inventory(self.root,self.binary)
        for item in (self.binary/delivery.BUNDLE_NAME).glob('extra-*'):item.unlink()
        for index in range(delivery.MAX_FILES*4+1):(self.binary/delivery.BUNDLE_NAME/f'empty-{index}').mkdir()
        with patch.object(delivery,'git',side_effect=self.git),self.assertRaises(ValueError):delivery.inventory(self.root,self.binary)

    def test_generated_bundle_plist_is_preserved_without_rewriting(self):
        (self.binary/delivery.BUNDLE_NAME/'Info.plist').write_bytes(b'generated fixture metadata')
        self.pack();target=self.base/'plist-qa';self.verify(target)
        self.assertEqual((target/delivery.BUNDLE_NAME/'Info.plist').read_bytes(),b'generated fixture metadata')

    def test_source_and_payload_symlinks_refuse(self):
        path=self.binary/delivery.BUNDLE_NAME/'profile.json';path.unlink();path.symlink_to(self.root/'Sources/AutoTechnoDSP/Resources/profile.json')
        with patch.object(delivery,'git',side_effect=self.git),self.assertRaises(ValueError):delivery.inventory(self.root,self.binary)

    def test_malformed_json_is_not_a_receipt(self):
        for raw in [b'{"x":1,"x":2}',b'{"x":NaN}',b'{"x":1e400}']:
            with self.assertRaises(ValueError):delivery.strict_json(raw)

    def test_original_file_reads_are_bounded_before_loading(self):
        path=self.base/'input'
        for raw in [b'',b'x'*17]:
            path.write_bytes(raw)
            with self.assertRaises(ValueError):delivery.bounded_file(path,16)
        path.write_bytes(b'exact')
        self.assertEqual(delivery.bounded_file(path,16),b'exact')

    def test_hosted_and_clean_source_guards_refuse_local_and_stale_builds(self):
        with patch.object(delivery.platform,'system',return_value='Linux'),self.assertRaises(ValueError):
            delivery.pack(self.root,self.binary,self.out,self.env)
        with patch.object(delivery,'git',return_value='stale'),self.assertRaises(ValueError):delivery.clean_source(self.root,SOURCE)
        with patch.object(delivery,'git',side_effect=[SOURCE,' M source']),self.assertRaises(ValueError):delivery.clean_source(self.root,SOURCE)
        self.assertFalse(self.out.exists())

    def test_source_bytes_are_rechecked_after_packaging(self):
        original=delivery.inventory;calls=[]
        def changed(*args):
            arch,rows=original(*args);calls.append(1)
            if len(calls)>1:rows[0]['sha256']='0'*64
            return arch,rows
        with patch.object(delivery,'inventory',side_effect=changed),self.assertRaises(ValueError):self.pack()
        self.assertFalse((self.out/'delivery.json').exists())


if __name__=='__main__':unittest.main()
