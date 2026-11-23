"""Offline structural checks for the BeamNG Eliminator repository.

Run with: python -m unittest discover -s tests -v
These checks do not replace an in-game BeamNG/BeamMP integration test.
"""

import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load_json(path):
    """Load JSON and reject duplicate object keys."""
    def reject_duplicate_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key!r}")
            result[key] = value
        return result

    with path.open(encoding="utf-8") as file:
        return json.load(file, object_pairs_hook=reject_duplicate_keys)


class ProjectStructureTests(unittest.TestCase):
    def test_required_paths_exist(self):
        for relative in (
            "server-plugin/modules",
            "client-mod/scripts/modScript.lua",
            "client-mod/lua/ge/extensions/eliminator.lua",
            "client-mod/lua/ge/extensions/eliminator",
            "shared/protocol",
            "shared/constants",
            "docs/research",
            "tools",
        ):
            with self.subTest(path=relative):
                self.assertTrue((ROOT / relative).exists())

    def test_every_json_file_is_valid(self):
        json_files = sorted(ROOT.rglob("*.json"))
        self.assertTrue(json_files, "No JSON files were found")
        for path in json_files:
            with self.subTest(path=path.relative_to(ROOT).as_posix()):
                load_json(path)

    def test_protocol_contract_matches_config(self):
        protocol = load_json(ROOT / "shared/protocol/protocol.json")
        rules = load_json(ROOT / "shared/constants/game-rules.json")
        config = load_json(ROOT / "server-plugin/config/config.example.json")

        self.assertIsInstance(protocol["protocol_version"], int)
        self.assertGreater(protocol["protocol_version"], 0)
        self.assertEqual(protocol["envelope"]["type"], "string")
        self.assertEqual(protocol["envelope"]["version"], "integer")
        self.assertEqual(protocol["envelope"]["payload"], "object")

        message_types = protocol["message_types"]
        self.assertTrue(message_types)
        self.assertEqual(len(message_types), len(set(message_types)))
        self.assertTrue(all(isinstance(item, str) and item for item in message_types))

        self.assertIn("match.snapshot", message_types)
        self.assertIn("match.countdown", message_types)

        self.assertEqual(config["network"]["protocol_version"], protocol["protocol_version"])
        self.assertEqual(config["match"]["competitor_limit"], rules["competitor_capacity"])
        self.assertGreaterEqual(config["match"]["minimum_human_players"], 1)
        self.assertLessEqual(
            config["match"]["minimum_human_players"],
            config["match"]["competitor_limit"],
        )

    def test_competitor_capacity_is_twenty(self):
        rules = load_json(ROOT / "shared/constants/game-rules.json")
        self.assertEqual(rules["competitor_capacity"], 20)

    def test_lua_roster_test_is_present(self):
        self.assertTrue((ROOT / "tests/lua/test_roster_manager.lua").is_file())

    def test_lua_match_manager_test_is_present(self):
        self.assertTrue((ROOT / "tests/lua/test_match_manager.lua").is_file())

    def test_match_manager_module_is_present(self):
        self.assertTrue((ROOT / "server-plugin/modules/match_manager.lua").is_file())

    def test_server_adapter_and_lua_test_are_present(self):
        self.assertTrue((ROOT / "server-plugin/main.lua").is_file())
        self.assertTrue((ROOT / "tests/lua/test_server_adapter.lua").is_file())

    def test_server_root_has_single_lua_entrypoint(self):
        root_lua = list((ROOT / "server-plugin").glob("*.lua"))
        self.assertEqual([path.name for path in root_lua], ["main.lua"])

    def test_client_modscript_loads_extension(self):
        script = (ROOT / "client-mod/scripts/modScript.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn('load("eliminator")', script)

    def test_lobby_ui_app_is_registered_and_complete(self):
        app_root = ROOT / "client-mod/ui/modules/apps/EliminatorLobby"
        for filename in ("app.json", "app.js", "app.html", "app.css", "app.png"):
            with self.subTest(filename=filename):
                self.assertTrue((app_root / filename).is_file())

        app = load_json(app_root / "app.json")
        script = (app_root / "app.js").read_text(encoding="utf-8")
        markup = (app_root / "app.html").read_text(encoding="utf-8")
        extension = (
            ROOT / "client-mod/lua/ge/extensions/eliminator.lua"
        ).read_text(encoding="utf-8")

        self.assertEqual(app["directive"], "eliminatorLobby")
        self.assertEqual(app["domElement"], "<eliminator-lobby></eliminator-lobby>")
        self.assertIn(".directive('eliminatorLobby'", script)
        self.assertIn("EliminatorLobbyUpdate", script)
        self.assertIn("extensions.eliminator.requestLobbySnapshot()", script)
        self.assertIn("guihooks.trigger(\"EliminatorLobbyUpdate\"", extension)
        self.assertIn("ng-repeat=\"slot in slots", markup)
        self.assertIn("ng-repeat=\"spectator in snapshot.spectators", markup)
        self.assertIn("i <= 20", script)


if __name__ == "__main__":
    unittest.main()
