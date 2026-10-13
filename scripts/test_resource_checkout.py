"""Exercise sealed resource byte preservation through real Git checkout filters."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest


class ResourceCheckoutTests(unittest.TestCase):
    def test_windows_text_conversion_preserves_every_sealed_json_resource(self):
        source = Path(__file__).resolve().parents[1]
        resources = sorted((source / 'Sources/AutoTechnoDSP/Resources').glob('*.json'))
        self.assertGreater(len(resources), 0)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            # Isolate ambient Git configuration, including user attributes.
            env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
            env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)

            def git(*args):
                return subprocess.run(['git', *args], cwd=root, env=env, check=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            git('init', '--quiet')
            (root / '.gitattributes').write_bytes((source / '.gitattributes').read_bytes())
            expected = {}
            for resource in resources:
                relative = resource.relative_to(source)
                raw = resource.read_bytes()
                self.assertNotIn(b'\r', raw, str(relative))
                expected[relative] = raw
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            control = Path('ordinary-text.txt')
            (root / control).write_bytes(b'checkout conversion control\n')
            git('-c', 'core.autocrlf=false', 'add', '.')
            for relative in [*expected, control]:
                (root / relative).unlink()
            git('-c', 'core.autocrlf=true', '-c', 'core.eol=crlf',
                'checkout-index', '--all', '--force')
            # Prove the Windows conversion was exercised, not merely configured.
            self.assertEqual((root / control).read_bytes(), b'checkout conversion control\r\n')
            for relative, raw in expected.items():
                with self.subTest(resource=str(relative)):
                    self.assertEqual((root / relative).read_bytes(), raw)


if __name__ == '__main__':
    unittest.main()
