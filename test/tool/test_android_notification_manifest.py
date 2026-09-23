"""Regressions for manifest changes that silently break OS delivery."""

import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "notification_manifest", ROOT / "tool/check_android_notification_manifest.py"
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)
A = CHECK.ANDROID


def valid_manifest():
    root = ET.Element("manifest")
    ET.SubElement(
        root,
        "uses-permission",
        {A + "name": "android.permission.RECEIVE_BOOT_COMPLETED"},
    )
    application = ET.SubElement(root, "application")
    ET.SubElement(
        application,
        "receiver",
        {A + "name": CHECK.DELIVERY_RECEIVER, A + "exported": "false"},
    )
    boot = ET.SubElement(
        application,
        "receiver",
        {A + "name": CHECK.BOOT_RECEIVER, A + "exported": "false"},
    )
    intent = ET.SubElement(boot, "intent-filter")
    for action in sorted(CHECK.BOOT_ACTIONS):
        ET.SubElement(intent, "action", {A + "name": action})
    return root


class NotificationManifestTest(unittest.TestCase):
    def validate(self, root):
        return CHECK.validate_manifest(ET.tostring(root))

    def test_source_manifest_can_deliver_and_restore_notifications(self):
        xml = (ROOT / "android/app/src/main/AndroidManifest.xml").read_bytes()
        self.assertEqual(CHECK.validate_manifest(xml), [])

    def test_valid_contract_without_explicit_enabled_is_accepted(self):
        self.assertEqual(self.validate(valid_manifest()), [])

    def test_missing_delivery_component_is_rejected_even_if_named_in_comment(self):
        root = valid_manifest()
        app = root.find("application")
        app.remove(app.find("receiver"))
        app.append(ET.Comment(CHECK.DELIVERY_RECEIVER))
        self.assertTrue(self.validate(root))

    def test_missing_boot_actions_are_individually_rejected(self):
        for missing in CHECK.BOOT_ACTIONS:
            with self.subTest(action=missing):
                root = valid_manifest()
                intent = root.find("application/receiver/intent-filter")
                for action in list(intent):
                    if action.get(A + "name") == missing:
                        intent.remove(action)
                self.assertTrue(any(missing in error for error in self.validate(root)))

    def test_exported_disabled_or_renamed_components_are_rejected(self):
        for receiver_name in (CHECK.DELIVERY_RECEIVER, CHECK.BOOT_RECEIVER):
            for key, value in (("exported", "true"), ("enabled", "false"), ("name", ".WrongReceiver")):
                with self.subTest(receiver=receiver_name, key=key):
                    root = valid_manifest()
                    receiver = next(
                        node for node in root.findall("application/receiver")
                        if node.get(A + "name") == receiver_name
                    )
                    receiver.set(A + key, value)
                    self.assertTrue(self.validate(root))

    def test_missing_exported_attribute_is_rejected(self):
        root = valid_manifest()
        del root.find("application/receiver").attrib[A + "exported"]
        self.assertTrue(self.validate(root))

    def test_receiver_must_be_direct_child_of_application(self):
        root = valid_manifest()
        app = root.find("application")
        receiver = app.find("receiver")
        app.remove(receiver)
        ET.SubElement(app, "activity").append(receiver)
        self.assertTrue(self.validate(root))

    def test_duplicate_receiver_declaration_is_rejected(self):
        root = valid_manifest()
        root.find("application").append(
            ET.fromstring(ET.tostring(root.find("application/receiver")))
        )
        self.assertTrue(self.validate(root))

    def test_disabled_application_is_rejected(self):
        root = valid_manifest()
        root.find("application").set(A + "enabled", "false")
        self.assertTrue(self.validate(root))

    def test_boot_permission_must_not_expire_on_newer_android(self):
        root = valid_manifest()
        root.find("uses-permission").set(A + "maxSdkVersion", "32")
        self.assertTrue(self.validate(root))
        root.remove(root.find("uses-permission"))
        self.assertTrue(self.validate(root))

    def test_invalid_xml_is_reported_as_failure(self):
        self.assertTrue(CHECK.validate_manifest("<manifest"))
        self.assertTrue(CHECK.validate_manifest("<application />"))


if __name__ == "__main__":
    unittest.main()
