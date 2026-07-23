#!/usr/bin/env python3
"""Executable contract tests for schema 2 template semantics."""

from __future__ import annotations

from dataclasses import dataclass
import unittest


MARKER = "（见图）"
RED_TOKEN = "{{red:（见图）}}"


@dataclass(frozen=True)
class Plan:
    text: str
    left: int
    red_text: str
    reset: bool


def render(template: str, date: str = "2001-03-13") -> Plan:
    output: list[str] = []
    cursor: int | None = None
    red_text = ""
    position = 0
    while position < len(template):
        opener = template.find("{{", position)
        closer_before = template.find("}}", position)
        if closer_before >= 0 and (opener < 0 or closer_before < opener):
            raise ValueError("unmatched closer")
        if opener < 0:
            output.append(template[position:])
            break
        output.append(template[position:opener])
        closer = template.find("}}", opener + 2)
        if closer < 0:
            raise ValueError("unmatched opener")
        if 0 <= template.find("{{", opener + 2) < closer:
            raise ValueError("nested")
        token = template[opener + 2 : closer]
        if token == "cursor":
            if cursor is not None:
                raise ValueError("multiple cursor")
            cursor = len("".join(output))
        elif token == "date":
            output.append(date)
        elif token == "red:（见图）":
            if red_text:
                raise ValueError("multiple red token")
            red_text = MARKER
            output.append(MARKER)
            if closer + 2 != len(template):
                raise ValueError("red token must be last")
        else:
            raise ValueError("unknown")
        position = closer + 2
    text = "".join(output)
    if cursor is None:
        cursor = len(text)
    left = len(text) - cursor
    return Plan(
        text=text,
        left=left,
        red_text=red_text,
        reset=bool(red_text) and left == 0,
    )


class TemplateEngineBehaviorTests(unittest.TestCase):
    def test_internal_cursor_skips_reset(self) -> None:
        plan = render(
            "放射性摄取增高，SUVmax约为{{cursor}}{{red:（见图）}}"
        )
        self.assertEqual(plan.text, "放射性摄取增高，SUVmax约为（见图）")
        self.assertEqual(plan.left, 4)
        self.assertEqual(plan.red_text, MARKER)
        self.assertFalse(plan.reset)

    def test_end_cursor_and_no_cursor_reset_red_suffix(self) -> None:
        for template in (
            "放射性摄取增高，SUVmax约为3.6{{red:（见图）}}",
        ):
            plan = render(template)
            self.assertEqual(plan.left, 0)
            self.assertTrue(plan.reset)

    def test_plain_date_is_black_and_evaluated_before_cursor_count(self) -> None:
        plain = render("检查日期：{{date}}")
        self.assertEqual(plain.text, "检查日期：2001-03-13")
        self.assertEqual(plain.left, 0)
        self.assertEqual(plain.red_text, "")
        self.assertFalse(plain.reset)

        internal = render(
            "检查日期：{{date}}，SUVmax约为{{cursor}}{{red:（见图）}}"
        )
        self.assertIn("2001-03-13", internal.text)
        self.assertEqual(internal.left, 4)
        self.assertFalse(internal.reset)

    def test_multiple_dates_and_cmx(self) -> None:
        dated = render("{{date}}/{{date}}")
        self.assertEqual(dated.text, "2001-03-13/2001-03-13")
        cmx = render("cm×{{cursor}}cm")
        self.assertEqual(cmx.text, "cm×cm")
        self.assertEqual(cmx.left, 2)
        self.assertEqual(cmx.red_text, "")

    def test_literal_marker_is_plain_black_text(self) -> None:
        literal = render("普通文字（见图）")
        self.assertEqual(literal.text, "普通文字（见图）")
        self.assertEqual(literal.red_text, "")
        self.assertFalse(literal.reset)

    def test_red_token_is_exact_and_must_be_last(self) -> None:
        for template in (
            "{{red:重要}}",
            "{{red:}}",
            f"{RED_TOKEN}正文",
            f"{RED_TOKEN}{{{{cursor}}}}",
            f"{RED_TOKEN}{{{{date}}}}",
            f"{RED_TOKEN}{RED_TOKEN}",
        ):
            with self.assertRaises(ValueError):
                render(template)

    def test_invalid_double_braces_and_literal_single_braces(self) -> None:
        for template in (
            "{{cursor}}{{cursor}}",
            "{{cursur}}",
            "{{unknown}}",
            "{{date",
            "date}}",
            "{{{{date}}",
        ):
            with self.assertRaises(ValueError):
                render(template)
        self.assertEqual(render("{ordinary}").text, "{ordinary}")


if __name__ == "__main__":
    unittest.main()
