import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/tv_web_receiver_html.dart';

void main() {
  test('a página da TV recebe e mostra curiosidades e notícias quando não há letra', () {
    final html = TvWebReceiverHtml.build();
    expect(html, contains("data.type === 'curiosities'"));
    expect(html, contains('id="curio"'));
    expect(html, contains("'About the record'"));
    expect(html, contains("'Latest news'"));
    // mesma regra do celular: 3 s de espera, até 12 s cada, uma a cada 10 s sem duração
    expect(html, contains('CURIO_LEAD = 3, CURIO_MAX = 12, CURIO_CYCLE = 10'));
    // nome da tela pela URL (segunda tela do Smart View), sem texto em português
    expect(html, contains("get('name') || 'TV'"));
    expect(html, isNot(contains('Navegador da TV')));
  });

  test('a TV confirma o ajuste manual da letra (±0.5 s) vindo do celular', () {
    final html = TvWebReceiverHtml.build();
    expect(html, contains('id="biasToast"'));
    expect(html, contains("typeof data.lyricBias === 'number'"));
  });
}
