import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/short_name.dart';

void main() {
  test('English names get shorter step by step', () {
    expect(autoShortNames('Introduction to Computer Science'), [
      'Introduction Computer Science',
      'Intr. Comp. Science',
      'Intr. Comp. Sci.',
      'Int. Com. Sci.',
      'ICS',
    ]);
    expect(autoShortNames('Linear Algebra'), ['Linear Alg.', 'Lin. Alg.']);
    expect(autoShortNames('Probability and Statistics'), [
      'Probability Statistics',
      'Prob. Stat.',
      'Pro. Sta.',
    ]);
  });

  test('numbers, roman numerals and acronyms stay whole', () {
    expect(autoShortNames('Calculus 2'), ['Calc. 2']);
    expect(autoShortNames('Physics II for Engineers (Electrical)'), [
      'Physics II Engineers',
      'Physics II Engin.',
      'Phys. II Eng.',
      'Phy. II Eng.',
    ]);
    expect(autoShortNames('Intro to AI'), ['Intro AI']);
  });

  test('a lone word is never cut to three letters', () {
    expect(autoShortNames('Thermodynamics'), ['Therm.', 'Ther.']);
  });

  test('Hebrew: a geresh for cut words, no guessed acronyms', () {
    expect(autoShortNames('מבוא למדעי המחשב'), ['מבוא למד׳ המח׳']);
    expect(autoShortNames('אלגברה לינארית'), [
      'אלגברה לינאר׳',
      'אלגב׳ לינא׳',
      'אלג׳ לינ׳',
    ]);
    expect(autoShortNames('פיזיקה 1מ'), ['פיזי׳ 1מ']);
  });

  test('short names have nothing to shorten', () {
    expect(autoShortNames('Lab'), isEmpty);
    expect(autoShortNames(''), isEmpty);
  });

  test('the editor suggests a form of up to 16 characters', () {
    expect(
      suggestedShortName('Introduction to Computer Science'),
      'Intr. Comp. Sci.',
    );
    expect(suggestedShortName('חשבון אינפיניטסימלי 1'), 'חשבון אינפי׳ 1');
    expect(suggestedShortName('Linear Algebra'), isNull);
  });
}
