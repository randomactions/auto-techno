"""Integrity and invalidation controls for the detached dependency foundation."""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_dependency_contract as dependency
import roadmap_contract_baseline as contracts


class DependencyContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run_git("init", "-q")
        self.run_git("config", "user.email", "fixture@example.invalid")
        self.run_git("config", "user.name", "Dependency fixture")
        for _, name in contracts.AUTHORITATIVE_DOCUMENTS:
            self.write(name, "{}\n")
        self.write("Package.swift", "fixture package\n")
        self.write("Sources/Owner.swift", "fixture source\n")
        self.write("Tests/Producer.swift", "fixture producer\n")
        self.write("scripts/shared.py", "fixture = 1\n")
        self.write("scripts/unrelated.py", "fixture = 2\n")
        for name in dependency.ANALYZERS.values():
            self.write("scripts/" + name, "import hashlib\nimport shared\n")
        for name in dependency.COMMON:
            self.write(name, "fixture = 1\n" if name.startswith("scripts/") else "fixture contract\n")
        self.write(".github/workflows/ci.yml", "fixture workflow\n")
        self.refresh_contract()
        self.run_git("add", ".")
        self.run_git("commit", "-qm", "fixture")
        self.context = {key: "0" * 64 if key in dependency.CONTEXT_HASHES else "fixture"
                        for key in dependency.CONTEXT_KEYS}
        self.context["corpusSha256"] = hashlib.sha256((self.root / "docs/BASELINE_CORPUS.json").read_bytes()).hexdigest()

    def run_git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, stderr=subprocess.PIPE)

    def write(self, name, text):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def refresh_contract(self):
        value = contracts.capture(self.root, 1)
        self.write("docs/ROADMAP_EXECUTION_BASELINE.json", json.dumps(value))

    def capture(self, context=None):
        self.run_git("add", ".")
        if self.run_git("status", "--porcelain").strip():
            self.run_git("commit", "-qm", "fixture mutation")
        value = dependency.capture(self.root, context or self.context)
        dependency.validate_snapshot(value, self.root)
        return value

    def assess(self, before, after):
        return dependency.assess(before, after, self.root)

    def reseal(self, value):
        value["snapshotFingerprint"] = dependency.digest({k: v for k, v in value.items()
                                                          if k != "snapshotFingerprint"})

    def test_unchanged_snapshot_is_exact_and_not_currency(self):
        before, after = self.capture(), self.capture()
        self.assertEqual(before, after)
        report = self.assess(before, after)
        self.assertEqual({x["action"] for x in report["families"].values()}, {"dependencies-unchanged"})
        self.assertFalse(report["qualification"]["artifactCurrencyEstablished"])
        self.assertEqual(report["legacyArtifacts"], "full-current-source-validation-still-required")

    def test_map_change_changes_execution_without_changing_producer_bindings(self):
        before = self.capture()
        self.write("docs/codebase-map.json", '{"changed":true}\n')
        self.refresh_contract()
        after = self.capture()
        self.assertNotEqual(before["executionFingerprint"], after["executionFingerprint"])
        for name in before["families"]:
            self.assertEqual(before["families"][name]["producerFingerprint"], after["families"][name]["producerFingerprint"])
        report = self.assess(before, after)
        self.assertEqual({x["action"] for x in report["families"].values()}, {"revalidation-required"})

    def test_source_test_resource_and_package_changes_recapture_every_dependent(self):
        for name in ["Sources/Owner.swift", "Sources/Policy/resource.json", "Tests/Producer.swift", "Package.swift"]:
            with self.subTest(name=name):
                before = self.capture()
                self.write(name, "changed fixture\n")
                self.refresh_contract()
                after = self.capture()
                report = self.assess(before, after)
                self.assertEqual({x["action"] for x in report["families"].values()}, {"recapture-required"})

    def test_added_and_deleted_compiled_input_are_not_ignored(self):
        before = self.capture()
        self.write("Sources/New.swift", "new fixture\n")
        after = self.capture()
        self.assertEqual(self.assess(before, after)["families"]["whole-mix-render"]["action"], "recapture-required")
        (self.root / "Sources/New.swift").unlink()
        self.assertEqual(self.assess(after, self.capture())["families"]["whole-mix-render"]["action"], "recapture-required")

    def test_shared_analyzer_change_reanalyzes_without_claiming_new_capture(self):
        before = self.capture()
        self.write("scripts/shared.py", "fixture = 3\n")
        report = self.assess(before, self.capture())
        self.assertEqual(report["families"]["whole-mix-render"]["action"], "reanalysis-required")
        self.assertEqual(report["families"]["long-horizon-session"]["action"], "recapture-required")
        self.assertFalse(report["qualification"]["promotionAuthorized"])

    def test_analyzer_is_specific_and_transitive(self):
        before = self.capture()
        self.write("scripts/stereo_compatibility_baseline_report.py", "import shared\nchanged = True\n")
        report = self.assess(before, self.capture())
        self.assertEqual(report["families"]["stereo-compatibility"]["action"], "reanalysis-required")
        self.assertEqual(report["families"]["whole-mix-render"]["action"], "revalidation-required")
        self.assertEqual(report["families"]["deficit-register"]["action"], "recapture-required")

    def test_changed_route_toolchain_state_and_python_are_distinguished(self):
        before = self.capture()
        for name in ["routeIdentityFingerprint", "initialStateFingerprint", "swiftCompilerIdentity", "pythonIdentity"]:
            with self.subTest(name=name):
                context = dict(self.context)
                context[name] = "1" * 64 if name in dependency.CONTEXT_HASHES else "changed"
                report = self.assess(before, self.capture(context))
                action = "reanalysis-required" if name == "pythonIdentity" else "recapture-required"
                self.assertEqual(report["families"]["whole-mix-render"]["action"], action)

    def test_unknown_dependency_refuses_reuse_even_with_other_hashes_unchanged(self):
        before = self.capture()
        self.write("native-helper/config.dat", "unknown fixture\n")
        report = self.assess(before, self.capture())
        self.assertEqual(report["unresolvedPaths"], ["native-helper/config.dat"])
        self.assertEqual({x["action"] for x in report["families"].values()}, {"recapture-required"})

    def test_unknown_local_import_and_dynamic_import_widen_tooling_closure(self):
        for text in ["import external_unknown\n", "import importlib\n", "__import__('shared')\n"]:
            self.write("scripts/baseline_render_manifest.py", text)
            value = self.capture()
            family = value["families"]["whole-mix-render"]
            self.assertTrue(family["conservativeToolingClosure"])
            self.assertIn("scripts/unrelated.py", family["analyzerInputs"])

    def test_stale_global_contract_still_refuses_capture(self):
        self.write("docs/CODEBASE_MAP.md", "stale fixture map\n")
        with self.assertRaisesRegex(dependency.DependencyContractError, "snapshot stale"):
            self.capture()

    def test_symlinks_traversal_missing_inputs_and_bad_context_refuse(self):
        (self.root / "Sources/Link.swift").symlink_to(self.root / "Sources/Owner.swift")
        with self.assertRaisesRegex(dependency.DependencyContractError, "symlink"):
            self.capture()
        (self.root / "Sources/Link.swift").unlink()
        for name in ["../outside", "Sources/../outside", "/outside", "Sources//x"]:
            with self.assertRaises(dependency.DependencyContractError):
                dependency.path_name(name)
        bad = dict(self.context)
        del bad["initialStateFingerprint"]
        with self.assertRaises(dependency.DependencyContractError):
            self.capture(bad)
        (self.root / "scripts/shared.py").unlink()
        self.write("scripts/baseline_render_manifest.py", "import shared\n")
        # A removed dependency cannot silently become an assumed stdlib import.
        value = self.capture()
        self.assertTrue(value["families"]["whole-mix-render"]["conservativeToolingClosure"])

    def test_old_incomplete_resealed_or_promotional_metadata_refuses(self):
        value = self.capture()
        for mutation in ["schema", "family", "promotion", "context", "producer", "hash", "execution", "corpus"]:
            bad = copy.deepcopy(value)
            if mutation == "schema": bad["schema"] = "legacy.v1"
            if mutation == "family": del bad["families"]["whole-mix-render"]
            if mutation == "promotion": bad["qualification"]["promotionAuthorized"] = True
            if mutation == "context": del bad["context"]["sdkIdentity"]
            if mutation == "producer": del bad["families"]["whole-mix-render"]["producerInputs"]["Tests/Producer.swift"]
            if mutation == "hash": bad["families"]["whole-mix-render"]["producerFingerprint"] = "f" * 64
            if mutation == "execution": bad["executionFingerprint"] = "f" * 64
            if mutation == "corpus": bad["context"]["corpusSha256"] = "f" * 64
            self.reseal(bad)
            with self.subTest(mutation=mutation), self.assertRaises(dependency.DependencyContractError):
                self.assess(bad, value)

    def test_dirty_origin_and_resealed_import_omission_refuse(self):
        before = self.capture()
        self.write("Sources/Owner.swift", "dirty fixture\n")
        with self.assertRaisesRegex(dependency.DependencyContractError, "clean committed"):
            dependency.capture(self.root, self.context)
        bad = copy.deepcopy(before)
        del bad["families"]["whole-mix-render"]["analyzerInputs"]["scripts/shared.py"]
        f = bad["families"]["whole-mix-render"]
        f["analysisFingerprint"] = dependency.digest({"files": f["analyzerInputs"],
            "pythonIdentity": bad["context"]["pythonIdentity"], "upstream": {}})
        self.reseal(bad)
        with self.assertRaisesRegex(dependency.DependencyContractError, "closure mismatch"):
            self.assess(bad, before)

    def test_resealed_false_origin_bytes_refuse(self):
        before = self.capture()
        bad = copy.deepcopy(before)
        bad["files"]["Sources/Owner.swift"]["sha256"] = "f" * 64
        self.reseal(bad)
        with self.assertRaisesRegex(dependency.DependencyContractError, "origin dependency bytes"):
            self.assess(bad, before)

    def test_duplicate_json_keys_refuse(self):
        self.write("duplicate.json", '{"schema":1,"schema":2}')
        with self.assertRaisesRegex(dependency.DependencyContractError, "duplicate"):
            dependency.read_json(self.root / "duplicate.json")


if __name__ == "__main__":
    unittest.main()
