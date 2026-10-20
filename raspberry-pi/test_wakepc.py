"""wakepc.py のユニットテスト。実行: python3 -m unittest test_wakepc.py"""

import unittest

from wakepc import build_magic_packet, parse_mac


class ParseMacTest(unittest.TestCase):
    def test_colon_separated(self):
        self.assertEqual(parse_mac("AA:BB:CC:DD:EE:FF"), bytes.fromhex("AABBCCDDEEFF"))

    def test_hyphen_separated_lowercase(self):
        self.assertEqual(parse_mac("aa-bb-cc-dd-ee-ff"), bytes.fromhex("AABBCCDDEEFF"))

    def test_no_separator(self):
        self.assertEqual(parse_mac("AABBCCDDEEFF"), bytes.fromhex("AABBCCDDEEFF"))

    def test_invalid(self):
        for bad in ["", "AA:BB:CC:DD:EE", "AA:BB:CC:DD:EE:GG", "AA:BB-CC:DD:EE:FF"]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                parse_mac(bad)


class BuildMagicPacketTest(unittest.TestCase):
    def test_structure(self):
        mac = bytes.fromhex("AABBCCDDEEFF")
        packet = build_magic_packet(mac)
        self.assertEqual(len(packet), 102)
        self.assertEqual(packet[:6], b"\xff" * 6)
        self.assertEqual(packet[6:], mac * 16)

    def test_wrong_length(self):
        with self.assertRaises(ValueError):
            build_magic_packet(b"\x00" * 5)


if __name__ == "__main__":
    unittest.main()
