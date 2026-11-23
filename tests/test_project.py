"""Offline structural checks for the BeamNG Eliminator repository.

Run with: python -m unittest discover -s tests -v
These checks do not replace an in-game BeamNG/BeamMP integration test.
"""

import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ProjectStructureTests(unittest.TestCase):
    def test_required_directories_exist(self):
        for relative in (
            "server-plugin/modules",
            "client-mod/lua/ge/extensions/eliminator",
            "shared/protocol",
            "shared/constants",
            "docs/research",
            "tools",
        ):
            with self.subTest(path=relative):
                self.assertTrue((ROOT / relative).is_dir())

    def test_json_files_are_valid(self):
        for relative in (
            "server-plugin/config/config.example.json",
            "shared/protocol/protocol.json",
            "shared/constants/game-rules.json",
        ):
            with self.subTest(path=relative):
                with (ROOT / relative).open(encoding="utf-8") as file:
                    json.load(file)

    def test_competitor_capacity_is_twenty(self):
        rules = json.loads(
            (ROOT / "shared/constants/game-rules.json").read_text(encoding="utf-8")
        )
        self.assertEqual(rules["competitor_capacity"], 20)

    def test_server_root_has_single_lua_entrypoint(self):
        root_lua = list((ROOT / "server-plugin").glob("*.lua"))
        self.assertEqual([path.name for path in root_lua], ["main.lua"])


if __name__ == "__main__":
    unittest.main()
