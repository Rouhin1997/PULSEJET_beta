#!/usr/bin/env python3
import math
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from pulsejet_xml_to_pulsarx import convert, C


def fixture(mode=True, jerk=0.003):
    root = ET.Element("peasoup_search")
    search = ET.SubElement(root, "search_parameters")
    ET.SubElement(search, "template_bank_file").text = "none"
    ET.SubElement(search, "size").text = "2048"
    if mode:
        ET.SubElement(search, "polynomial_template_bank_file").text = "bank.txt"
        ET.SubElement(search, "polynomial_reference_epoch").text = "segment_midpoint"
    segment = ET.SubElement(root, "segment_parameters")
    for tag, val in {"segment_pepoch": "59000.111111111111",
                     "segment_start_sample": "4096",
                     "segment_nsamples": "2048"}.items():
        ET.SubElement(segment, tag).text = val
    header = ET.SubElement(root, "header_parameters")
    ET.SubElement(header, "tsamp").text = "0.000125"
    cs = ET.SubElement(root, "candidates")
    for i, (p, a, j, snr) in enumerate([(0.01, 120.0, jerk, 15),
                                        (0.02, -120.0, -jerk, 9)]):
        c = ET.SubElement(cs, "candidate", id=str(i))
        for tag, val in dict(period=p, acc=a, jerk=j, dm=42+i,
                             snr=snr, pb=0).items():
            ET.SubElement(c, tag).text = str(val)
    return ET.ElementTree(root)


class TestConversion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.xml = Path(self.tmp.name) / "overview.xml"

    def tearDown(self):
        self.tmp.cleanup()

    def test_motion_derivatives_and_epoch(self):
        fixture().write(self.xml, encoding="unicode")
        items, meta = convert(self.xml)
        self.assertEqual(len(items), 2)
        self.assertEqual(meta["start_sample"], 4096)
        self.assertEqual(meta["fft_size"], "2048")
        self.assertAlmostEqual(meta["reference_epoch_mjd"], 59000.111111111111)
        self.assertAlmostEqual(items[0]["f0"], 100)
        self.assertAlmostEqual(items[0]["f1"], -120 * 100 / C)
        self.assertAlmostEqual(items[0]["f2"], 100 * (2*(120/C)**2 - .003/C))
        self.assertGreater(items[1]["f1"], 0)

    def test_reject_unverified_xml(self):
        fixture(mode=False).write(self.xml, encoding="unicode")
        with self.assertRaisesRegex(ValueError, "midpoint metadata"):
            convert(self.xml)
        self.assertEqual(len(convert(self.xml, allow_legacy=True)[0]), 2)

    def test_top_snr_selection(self):
        fixture().write(self.xml, encoding="unicode")
        self.assertEqual(convert(self.xml, min_snr=10)[0][0]["id"], 0)
        self.assertEqual(len(convert(self.xml, limit=1)[0]), 1)

    def test_reject_invalid_values(self):
        root = fixture().getroot()
        root.find("candidates/candidate/period").text = "nan"
        ET.ElementTree(root).write(self.xml, encoding="unicode")
        with self.assertRaisesRegex(ValueError, "Non-finite"):
            convert(self.xml)

    def test_reject_keplerian(self):
        root = fixture().getroot()
        root.find("search_parameters/template_bank_file").text = "orbit.txt"
        ET.ElementTree(root).write(self.xml, encoding="unicode")
        with self.assertRaisesRegex(ValueError, "Keplerian"):
            convert(self.xml)


if __name__ == "__main__":
    unittest.main()
