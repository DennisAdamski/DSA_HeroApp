import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from import_liber_cantiones import (
    SpellBlock,
    TocEntry,
    _build_catalog_indexes,
    _match_spell,
    _parse_spell_fields,
    _split_modifications_and_variants,
)


class LiberCantionesImportTest(unittest.TestCase):
    def test_split_modifications_and_variants(self) -> None:
        raw = (
            'Zauberdauer, Kosten, Reichweite\n'
            '◆ Blitzgeschwind (+7). Mehr Tempo.\n'
            '◆ Koboldisch. Nur Sprache.'
        )

        modifications, variants = _split_modifications_and_variants(raw)

        self.assertEqual(modifications, 'Zauberdauer, Kosten, Reichweite')
        self.assertEqual(
            variants,
            [
                'Blitzgeschwind (+7). Mehr Tempo.',
                'Koboldisch. Nur Sprache.',
            ],
        )

    def test_parse_spell_fields_extracts_required_sections(self) -> None:
        block = '''
Zauberdauer: 2 Aktionen
Wirkung: Der Zauber beschleunigt das Ziel.
Kosten: 7 AsP
Zielobjekt: Einzelperson, freiwillig
Reichweite: selbst, 7 Schritt
Wirkungsdauer: ZfP* mal 3 Kampfrunden (A)
Modifikationen und Varianten: Zauberdauer, Kosten, Zielobjekt
◆ Blitzgeschwind (+7). Mehr Tempo.
◆ Koboldisch. Nur Sprache.
Reversalis: Irgendetwas anderes.
'''.strip()

        parsed = _parse_spell_fields(block)

        self.assertEqual(parsed['castingTime'], '2 Aktionen')
        self.assertEqual(parsed['wirkung'], 'Der Zauber beschleunigt das Ziel.')
        self.assertEqual(parsed['aspCost'], '7 AsP')
        self.assertEqual(parsed['targetObject'], 'Einzelperson, freiwillig')
        self.assertEqual(parsed['range'], 'selbst, 7 Schritt')
        self.assertEqual(parsed['duration'], 'ZfP* mal 3 Kampfrunden (A)')
        self.assertEqual(parsed['modifications'], 'Zauberdauer, Kosten, Zielobjekt')
        self.assertEqual(
            parsed['variants'],
            [
                'Blitzgeschwind (+7). Mehr Tempo.',
                'Koboldisch. Nur Sprache.',
            ],
        )

    def test_match_spell_uses_prefix_with_probe_for_subtitle_catalog_entries(self) -> None:
        catalog = [
            {
                'id': 'spell_axxeleratus_blitzgeschwind',
                'name': 'Axxeleratus Blitzgeschwind',
                'attributes': ['Klugheit', 'Gewandheit', 'Konstitution'],
            },
            {
                'id': 'spell_balsam_salabunde',
                'name': 'Balsam Salabunde',
                'attributes': ['Klugheit', 'Intuition', 'Charisma'],
            },
        ]
        indexes = _build_catalog_indexes(catalog)
        block = SpellBlock(
            toc=TocEntry(
                printed_page=36,
                raw_name='Axxeleratus',
                probe='kl/ge/ko',
                complexity='C',
            ),
            pdf_start_page=37,
            pdf_end_page=37,
            title='',
            probe='kl/ge/ko',
            text='Wirkung: Test',
        )

        spell, reason = _match_spell(block, indexes)

        self.assertIsNotNone(spell)
        self.assertEqual(spell['id'], 'spell_axxeleratus_blitzgeschwind')
        self.assertEqual(reason, 'stripped_subtitle')


if __name__ == '__main__':
    unittest.main()
