import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/dateiname.dart';

void main() {
  test('verbotene Zeichen, auch der Backslash, werden zu Unterstrichen', () {
    expect(
      bereinigeDateiname(r'a<b>c:d"e/f\g|h?i*j', fallback: 'x'),
      'a_b_c_d_e_f_g_h_i_j',
    );
  });

  test('leere Namen nehmen den Ersatz', () {
    expect(bereinigeDateiname('   ', fallback: 'held'), 'held');
    expect(bereinigeDateiname(' Alrik ', fallback: 'held'), 'Alrik');
  });
}
