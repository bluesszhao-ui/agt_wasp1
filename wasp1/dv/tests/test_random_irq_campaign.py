#!/usr/bin/env python3
"""Unit tests for the deterministic random-IRQ campaign driver."""

from __future__ import annotations

import argparse
import unittest

from wasp1_random_irq_multiseed import (
    ROUNDS_PER_SEED,
    build_summary,
    generate_seed_campaign,
    parse_pass_output,
    parse_seed,
    require_complete_selector_coverage,
    selector_histogram,
    xorshift32,
)


class RandomIrqCampaignTest(unittest.TestCase):
    """Check seed generation, result parsing, and aggregate coverage gates."""

    def test_seed_generator_is_deterministic_unique_and_nonzero(self) -> None:
        first = generate_seed_campaign(0xC001D00D, 32)
        second = generate_seed_campaign(0xC001D00D, 32)
        self.assertEqual(first, second)
        self.assertEqual(len(first), len(set(first)))
        self.assertNotIn(0, first)

        scheduled_states: set[int] = set()
        for seed in first:
            state = seed
            for _ in range(ROUNDS_PER_SEED):
                state = xorshift32(state)
                self.assertNotIn(state, scheduled_states)
                scheduled_states.add(state)
        self.assertEqual(len(scheduled_states), 32 * ROUNDS_PER_SEED)

    def test_zero_seed_is_rejected(self) -> None:
        with self.assertRaises(argparse.ArgumentTypeError):
            parse_seed("0")

    def test_selector_trace_decodes_two_bit_rounds(self) -> None:
        self.assertEqual(selector_histogram(0xE4, rounds=4), [1, 1, 1, 1])

    def test_pass_line_parses_all_checked_results(self) -> None:
        output = (
            "Random IRQ stress: seed=0x12345678 state=0x4e0f25f8 "
            "trace=0x0007540d events=14 timer=7 dma=7 gpio=0 "
            "event_sum=0x00001959 data_sum=0x089abcde PASS\n"
        )
        record = parse_pass_output(output, 0x12345678)
        self.assertEqual(record["events"], 14)
        self.assertEqual(sum(record["selectors"]), 12)
        self.assertEqual(record["event_sum"], "0x00001959")

    def test_campaign_requires_every_selector(self) -> None:
        records = [
            {
                "seed": "0x00000001",
                "state": "0x00000002",
                "trace": "0x00000000",
                "events": 12,
                "timer": 12,
                "dma": 0,
                "gpio": 0,
                "event_sum": "0x00000000",
                "data_sum": "0x00000000",
                "selectors": [12, 0, 0, 0],
            }
        ]
        summary = build_summary(records, "explicit", None)
        with self.assertRaises(ValueError):
            require_complete_selector_coverage(summary)


if __name__ == "__main__":
    unittest.main()
