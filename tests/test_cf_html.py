#!/usr/bin/env python3
"""Platform-independent reference checks for the CF_HTML byte-offset contract.

These tests mirror BuildCfHtml() and validate the wire format. They do not test
AutoHotkey or Windows clipboard integration.
"""

from __future__ import annotations

import html
import re
import unittest


START_MARKER = "<!--StartFragment-->"
END_MARKER = "<!--EndFragment-->"
HEADER_TEMPLATE = (
    "Version:1.0\r\n"
    "StartHTML:0000000000\r\n"
    "EndHTML:0000000000\r\n"
    "StartFragment:0000000000\r\n"
    "EndFragment:0000000000\r\n"
)


def build_cf_html(fragment: str) -> bytes:
    html_prefix = f"<html><body>{START_MARKER}"
    html_suffix = f"{END_MARKER}</body></html>"
    html_text = f"{html_prefix}{fragment}{html_suffix}"

    start_html = len(HEADER_TEMPLATE.encode("utf-8"))
    start_fragment = start_html + len(html_prefix.encode("utf-8"))
    end_fragment = start_fragment + len(fragment.encode("utf-8"))
    end_html = start_html + len(html_text.encode("utf-8"))

    header = (
        "Version:1.0\r\n"
        f"StartHTML:{start_html:010d}\r\n"
        f"EndHTML:{end_html:010d}\r\n"
        f"StartFragment:{start_fragment:010d}\r\n"
        f"EndFragment:{end_fragment:010d}\r\n"
    )
    assert len(header.encode("utf-8")) == start_html
    return f"{header}{html_text}".encode("utf-8")


def parse_offsets(payload: bytes) -> dict[str, int]:
    header = payload[: payload.index(b"<html>")].decode("ascii")
    fields = re.findall(
        r"^(StartHTML|EndHTML|StartFragment|EndFragment):(\d{10})\r?$",
        header,
        re.MULTILINE,
    )
    return {name: int(value) for name, value in fields}


class CfHtmlOffsetTests(unittest.TestCase):
    CASES = (
        "ASCII text",
        "（见图）",
        "SUVmax约（见图）",
        html.escape('<tag attr="value"> & text', quote=True).replace("&#x27;", "&#39;"),
        "first line\n第二行",
    )

    def test_offsets_for_utf8_fragments(self) -> None:
        for fragment in self.CASES:
            with self.subTest(fragment=fragment):
                payload = build_cf_html(fragment)
                offsets = parse_offsets(payload)

                start_html = offsets["StartHTML"]
                end_html = offsets["EndHTML"]
                start_fragment = offsets["StartFragment"]
                end_fragment = offsets["EndFragment"]

                self.assertEqual(payload[start_html : start_html + 6], b"<html>")
                self.assertEqual(end_html, len(payload))
                self.assertEqual(payload[start_fragment:end_fragment], fragment.encode("utf-8"))
                self.assertEqual(payload[end_fragment : end_fragment + len(END_MARKER)], END_MARKER.encode("ascii"))
                self.assertLessEqual(start_html, start_fragment)
                self.assertLessEqual(start_fragment, end_fragment)
                self.assertLessEqual(end_fragment, end_html)

    def test_chinese_offsets_use_bytes_not_characters(self) -> None:
        fragment = "（见图）"
        payload = build_cf_html(fragment)
        offsets = parse_offsets(payload)
        byte_length = offsets["EndFragment"] - offsets["StartFragment"]

        self.assertEqual(byte_length, len(fragment.encode("utf-8")))
        self.assertNotEqual(byte_length, len(fragment))

    def test_payload_has_no_terminating_nul(self) -> None:
        payload = build_cf_html("（见图）")
        offsets = parse_offsets(payload)

        self.assertFalse(payload.endswith(b"\x00"))
        self.assertEqual(offsets["EndHTML"], len(payload))


if __name__ == "__main__":
    unittest.main()
