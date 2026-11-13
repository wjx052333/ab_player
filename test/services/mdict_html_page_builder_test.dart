import 'package:audacity_player/services/mdict/mdict_html_page_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds a speaker icon to bare sound links', () {
    const html = '<a href="sound://audio/a b.mp3" title="朗读"><font>I got it.</font></a>';
    final out = MDictHtmlPageBuilder.addSpeakerIcons(html);
    expect(out, contains('<span class="mdd-play">'));
    expect(out.indexOf('mdd-play'), lessThan(out.indexOf('I got it.')));
  });

  test('leaves links that already have an icon image or no text alone', () {
    const withImg = '<a href="sound://x.mp3"><img src="img/spkr_r.png"></a>';
    const empty = '<a href="sound://x.mp3"> </a>';
    expect(MDictHtmlPageBuilder.addSpeakerIcons(withImg), withImg);
    expect(MDictHtmlPageBuilder.addSpeakerIcons(empty), empty);
  });

  test('build() applies it and the dark font override', () async {
    final page = await MDictHtmlPageBuilder.build(
      html: '<a href="sound://t.mp3"><font color="#0">test</font></a>',
    );
    expect(page, contains('mdd-play'));
    expect(page, contains('font[color="#0"]'));
  });
}
