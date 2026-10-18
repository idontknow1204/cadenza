import datetime as dt
import importlib.util
import pathlib
import sys
import unittest


SCRIPT = pathlib.Path(__file__).parents[1] / "import_curated_jobs.py"
SPEC = importlib.util.spec_from_file_location("jobs_importer", SCRIPT)
jobs_importer = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = jobs_importer
SPEC.loader.exec_module(jobs_importer)


class OpportunityImporterTests(unittest.TestCase):
    def test_munich_parser_keeps_official_schedule_and_dates(self):
        source, parser = jobs_importer.SOURCES[0]
        text = """
        Gesucht werden
        SOLO-POSAUNE
        Probespieltermin: 20.10.2027 (Bewerbungsfrist: 04.10.2027)
        Orchesterakademie
        FLÖTE
        Probespieltermin: 12.11.2027 (Bewerbungsfrist: 05.10.2027)
        """

        items = parser(source, text)

        self.assertEqual(len(items), 2)
        self.assertEqual(items[0].deadline, "2027-10-04")
        self.assertEqual(items[0].event_start, "2027-10-20")
        self.assertEqual(items[0].instruments, ["트롬본"])
        self.assertIn("Probespieltermin", items[0].description)
        self.assertTrue(items[1].has_scholarship)

    def test_oper_frankfurt_parser_extracts_position(self):
        source, parser = jobs_importer.SOURCES[1]
        text = """
        Stellenangebote des Orchesters
        Das Opern- und Museumsorchester sucht
        Eine Solo-Posaune
        Probespiel nach Einladung
        Informationen zur Bewerbung
        """

        items = parser(source, text)

        self.assertEqual(len(items), 1)
        self.assertIn("Solo-Posaune", items[0].title)
        self.assertEqual(items[0].instruments, ["트롬본"])

    def test_karajan_parser_marks_academy_listing(self):
        source, parser = jobs_importer.SOURCES[2]
        text = """
        Vacancies
        VIOLIN (2)
        Application deadline: 14 November 2027
        Scholarship holders receive a monthly stipend.
        """

        items = parser(source, text)

        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].job_type, "audition")
        self.assertTrue(items[0].has_scholarship)
        self.assertEqual(items[0].deadline, "2027-11-14")

    def test_stable_key_ignores_title_spacing_and_punctuation(self):
        source = jobs_importer.SOURCES[0][0]
        base = self._item("Solo Trombone")
        variant = self._item("  Solo—Trombone! ")

        self.assertEqual(
            jobs_importer.external_key(source, base),
            jobs_importer.external_key(source, variant),
        )

    def test_quality_gate_rejects_missing_instrument_and_bad_date(self):
        item = self._item("Orchestra member")
        item.instruments = []
        item.deadline = "2027-44-99"

        errors, _ = jobs_importer.validate_item(item)

        self.assertIn("instrument", errors)
        self.assertIn("deadline", errors)

    def test_normalization_filters_expired_rows(self):
        source = jobs_importer.SOURCES[0][0]
        expired = self._item("Solo Trombone")
        expired.deadline = (dt.date.today() - dt.timedelta(days=1)).isoformat()

        items, warnings = jobs_importer.normalize_items(source, [expired])

        self.assertEqual(items, [])
        self.assertTrue(any("expired" in warning for warning in warnings))

    def test_bulk_payload_keeps_nullable_columns(self):
        source = jobs_importer.SOURCES[0][0]
        payload = jobs_importer.public_payload("source-id", source, self._item("Solo Trombone"), None)

        self.assertIn("deadline", payload)
        self.assertIsNone(payload["deadline"])
        self.assertIn("user_id", payload)
        self.assertIsNone(payload["user_id"])

    @staticmethod
    def _item(title):
        source = jobs_importer.SOURCES[0][0]
        return jobs_importer.Opportunity(
            title=title,
            organization=source.organization,
            location=source.location,
            city_id=source.city_id,
            source_url=source.url,
            source_language=source.language,
            instruments=["트롬본"],
            description="Official vacancy details from the institution.",
        )


if __name__ == "__main__":
    unittest.main()
