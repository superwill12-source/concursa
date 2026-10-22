import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const api = String.fromEnvironment('API', defaultValue: 'http://10.0.2.2:8000');
String prov = 'gemini', key = '', model = '';
Map<String, String> hd() => {
  'Content-Type': 'application/json',
  'X-IA-Provider': prov,
  'X-IA-Key': key,
  'X-IA-Model': model,
};

Future<dynamic> get(String p) async {
  if (api.isEmpty) throw Exception('Servidor não configurado. Configure API_URL no GitHub Actions.');
  final r = await http.get(Uri.parse('$api$p'), headers: hd()).timeout(const Duration(seconds: 20));
  if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Erro HTTP ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes));
}

Future<dynamic> post(String p, Map b) async {
  if (api.isEmpty) throw Exception('Servidor não configurado. Configure API_URL no GitHub Actions.');
  final r = await http.post(Uri.parse('$api$p'), headers: hd(), body: jsonEncode(b))
      .timeout(const Duration(seconds: 120));
  if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Erro HTTP ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes));
}

const provs = {
  'gemini': 'Google Gemini (grátis)',
  'groq': 'Groq (grátis)',
  'openrouter': 'OpenRouter (modelos grátis)',
  'openai': 'ChatGPT / OpenAI',
  'anthropic': 'Claude / Anthropic',
  'deepseek': 'DeepSeek',
  'mistral': 'Mistral',
};
const links = {
  'gemini': 'aistudio.google.com/apikey',
  'groq': 'console.groq.com/keys',
  'openrouter': 'openrouter.ai/keys',
  'openai': 'platform.openai.com/api-keys',
  'anthropic': 'console.anthropic.com',
  'deepseek': 'platform.deepseek.com',
  'mistral': 'console.mistral.ai',
};

void configIA(BuildContext c) {
  final kc = TextEditingController(text: key);
  final mc = TextEditingController(text: model);
  showDialog(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    title: const Text('Sua IA'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(
        isExpanded: true, value: prov,
        items: [for (final e in provs.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => set(() => prov = v!),
      ),
      Text('Entre em ${links[prov]} para criar uma chave e cole abaixo.'),
      TextField(controller: kc, obscureText: true, decoration: const InputDecoration(labelText: 'Chave de API')),
      TextField(controller: mc, decoration: const InputDecoration(labelText: 'Modelo (opcional)')),
    ])),
    actions: [TextButton(onPressed: () async {
      key = kc.text.trim();
      model = mc.text.trim();
      final p = await SharedPreferences.getInstance();
      await p.setString('prov', prov);
      await p.setString('key', key);
      await p.setString('model', model);
      if (ctx.mounted) Navigator.pop(ctx);
    }, child: const Text('Salvar'))],
  )));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final p = await SharedPreferences.getInstance();
    prov = p.getString('prov') ?? 'gemini';
    key = p.getString('key') ?? '';
    model = p.getString('model') ?? '';
  } catch (_) {}
  runApp(MaterialApp(
    title: 'Concursa',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3A3FD6), useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF3A3FD6), brightness: Brightness.dark, useMaterial3: true),
    home: const Home(),
  ));
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  int index = 0;
  final pages = const [Concursos(), Estudar(), QuestoesTela(), Simulado()];
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(['Concursos', 'Estudar', 'Questões', 'Simulados'][index]),
      actions: [IconButton(tooltip: 'Configurar IA', icon: const Icon(Icons.smart_toy_outlined), onPressed: () => configIA(c))],
    ),
    body: SafeArea(child: pages[index]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Concursos'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Estudar'),
        NavigationDestination(icon: Icon(Icons.manage_search), label: 'Questões'),
        NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Simulados'),
      ],
    ),
  );
}

class Concursos extends StatefulWidget {
  const Concursos({super.key});
  @override State<Concursos> createState() => _ConcursosState();
}
class _ConcursosState extends State<Concursos> {
  String status = '', uf = '';
  @override Widget build(BuildContext c) => Column(children: [
    Padding(padding: const EdgeInsets.all(8), child: Wrap(spacing: 8, children: [
      for (final s in ['', 'aberto', 'previsto'])
        ChoiceChip(label: Text(s.isEmpty ? 'Todos' : s == 'aberto' ? 'Abertos' : 'Previstos'),
          selected: status == s, onSelected: (_) => setState(() => status = s)),
      DropdownButton<String>(
        value: uf, items: ['', 'SP', 'MG', 'RJ', 'BA', 'RS', 'PR', 'PE', 'CE', 'DF']
          .map((u) => DropdownMenuItem(value: u, child: Text(u.isEmpty ? 'Brasil' : u))).toList(),
        onChanged: (v) => setState(() => uf = v ?? ''),
      ),
    ])),
    Expanded(child: FutureBuilder(
      future: get('/concursos?uf=$uf&status=$status'),
      builder: (_, s) {
        if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Não consegui conectar ao servidor.\n${s.error}')));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final l = s.data as List;
        if (l.isEmpty) return const Center(child: Text('Nenhum concurso encontrado.'));
        return ListView(children: [for (final d in l) Card(child: ListTile(
          title: Text('${d['titulo'] ?? 'Concurso'}'),
          subtitle: Text('${d['uf'] ?? ''} · ${d['status'] ?? ''}\nToque para abrir a notícia'),
          isThreeLine: true, trailing: Icon(d['status'] == 'aberto' ? Icons.check_circle_outline : Icons.schedule),
          onTap: () => launchUrl(Uri.parse('${d['link']}'), mode: LaunchMode.externalApplication),
        ))]);
      },
    )),
  ]);
}

class Estudar extends StatefulWidget {
  const Estudar({super.key});
  @override State<Estudar> createState() => _EstudarState();
}
class _EstudarState extends State<Estudar> {
  final controller = TextEditingController();
  String? output;
  bool loading = false;
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
    TextField(controller: controller, maxLines: 6, decoration: const InputDecoration(
      labelText: 'Conteúdo programático do edital', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    FilledButton(onPressed: loading ? null : () async {
      setState(() => loading = true);
      try {
        final r = await post('/apostila', {'conteudo': controller.text});
        if (mounted) setState(() => output = '${r['apostila'] ?? 'Nenhum conteúdo retornado.'}');
      } catch (e) {
        if (mounted) setState(() => output = 'Não foi possível gerar a apostila.\n$e');
      } finally { if (mounted) setState(() => loading = false); }
    }, child: Text(loading ? 'Gerando… pode levar minutos' : 'Gerar apostila')),
    if (output != null) Padding(padding: const EdgeInsets.only(top: 16), child: SelectableText(output!)),
  ]);
}

class QCard extends StatefulWidget {
  final Map q;
  final void Function(bool)? onAnswer;
  const QCard(this.q, {this.onAnswer, super.key});
  @override State<QCard> createState() => _QCardState();
}
class _QCardState extends State<QCard> {
  String? selected;
  List? comments;
  @override Widget build(BuildContext c) {
    final q = widget.q;
    final alts = (q['alts'] as List? ?? []);
    return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 4, children: [
          _chip('${q['banca'] ?? 'Banca não informada'}'),
          _chip('${q['ano'] ?? 'Ano n/i'}'),
          _chip('${q['materia'] ?? 'Matéria n/i'}'),
          _chip('${q['nivel'] ?? 'Nível n/i'}'),
        ]),
        const SizedBox(height: 12),
        Text('${q['enunciado'] ?? ''}', style: Theme.of(c).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final a in alts) Card(
          elevation: 0,
          color: selected == null ? Theme.of(c).colorScheme.surfaceContainerHighest :
            '${a[0]}' == '${q['gabarito']}' ? Colors.green.withOpacity(.18) :
            '${a[0]}' == selected ? Colors.red.withOpacity(.16) : null,
          child: ListTile(
            dense: true, title: Text('${a[0]}) ${a[1]}'),
            trailing: selected != null && '${a[0]}' == '${q['gabarito']}' ? const Icon(Icons.check_circle, color: Colors.green) : null,
            onTap: selected != null ? null : () {
              setState(() => selected = '${a[0]}');
              widget.onAnswer?.call('${a[0]}' == '${q['gabarito']}');
            },
          ),
        ),
        if (selected != null) Row(children: [
          Icon(selected == '${q['gabarito']}' ? Icons.check_circle : Icons.cancel,
            color: selected == '${q['gabarito']}' ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(selected == '${q['gabarito']}' ? 'Resposta correta!' : 'Resposta incorreta. Gabarito: ${q['gabarito']}')),
        ]),
        if (selected != null && q['id'] is int && (q['id'] as int) > 0)
          TextButton.icon(onPressed: () async {
            try {
              final r = await get('/questoes/${q['id']}/comentarios');
              if (mounted) setState(() => comments = r as List);
            } catch (e) {
              if (mounted) setState(() => comments = [{'autor':'Sistema','texto':'Comentários indisponíveis: $e'}]);
            }
          }, icon: const Icon(Icons.lightbulb_outline), label: const Text('Ver resolução/comentários')),
        if (comments != null) for (final m in comments!)
          ListTile(dense: true, leading: const Icon(Icons.chat_bubble_outline),
            title: Text('${m['autor'] ?? 'Comentário'}'), subtitle: Text('${m['texto'] ?? ''}')),
      ]),
    ));
  }
  Widget _chip(String t) => Chip(label: Text(t, style: const TextStyle(fontSize: 11)),
    visualDensity: VisualDensity.compact, padding: EdgeInsets.zero);
}

class QuestoesTela extends StatefulWidget {
  const QuestoesTela({super.key});
  @override State<QuestoesTela> createState() => _QuestoesTelaState();
}
class _QuestoesTelaState extends State<QuestoesTela> {
  final searchController = TextEditingController();
  List<String> bancas = [], materias = [], niveis = ['facil', 'medio', 'dificil'];
  List<int> anos = [];
  List<Map<String, dynamic>> questoes = [];
  String banca = '', materia = '', nivel = '', ordem = 'recentes';
  int ano = 0, total = 0;
  bool loading = false, loadingMore = false;
  String? error;

  @override void initState() { super.initState(); _init(); }
  @override void dispose() { searchController.dispose(); super.dispose(); }

  Future<void> _init() async {
    await _loadFilters();
    await _search(reset: true);
  }
  Future<void> _loadFilters() async {
    try {
      final r = await get('/questoes/filtros') as Map;
      if (!mounted) return;
      setState(() {
        bancas = (r['bancas'] as List? ?? []).map((e) => '$e').toList();
        materias = (r['materias'] as List? ?? []).map((e) => '$e').toList();
        anos = (r['anos'] as List? ?? []).map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList();
        niveis = (r['niveis'] as List? ?? ['facil', 'medio', 'dificil']).map((e) => '$e').toList();
      });
    } catch (_) {
      // Se o endpoint de filtros falhar, os campos ainda permitem busca básica.
    }
  }
  String _labelNivel(String n) => {'facil':'Fácil','medio':'Médio','dificil':'Difícil'}[n] ?? n;

  Future<void> _search({required bool reset}) async {
    if (reset) {
      setState(() { loading = true; error = null; });
    } else {
      setState(() => loadingMore = true);
    }
    final params = <String, String>{
      'limit': '20', 'offset': reset ? '0' : '${questoes.length}', 'ordem': ordem,
    };
    if (searchController.text.trim().isNotEmpty) params['busca'] = searchController.text.trim();
    if (banca.isNotEmpty) params['banca'] = banca;
    if (materia.isNotEmpty) params['materia'] = materia;
    if (ano > 0) params['ano'] = '$ano';
    if (nivel.isNotEmpty) params['nivel'] = nivel;
    try {
      final r = await get('/questoes/pesquisa?${Uri(queryParameters: params).query}') as Map;
      final items = (r['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        if (reset) questoes = items; else questoes.addAll(items);
        total = int.tryParse('${r['total'] ?? items.length}') ?? items.length;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Falha ao buscar questões. Verifique se o servidor foi atualizado.\n$e');
    } finally {
      if (mounted) setState(() { loading = false; loadingMore = false; });
    }
  }
  void _clear() {
    searchController.clear();
    setState(() { banca = ''; materia = ''; ano = 0; nivel = ''; ordem = 'recentes'; });
    _search(reset: true);
  }
  @override Widget build(BuildContext c) {
    final canLoadMore = questoes.length < total && questoes.isNotEmpty;
    return Column(children: [
      Material(elevation: 1, color: Theme.of(c).colorScheme.surface, child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(children: [
          TextField(controller: searchController, textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(reset: true),
            decoration: InputDecoration(
              hintText: 'Buscar enunciado, assunto ou palavra-chave',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: () => _search(reset: true), icon: const Icon(Icons.arrow_forward)),
              border: const OutlineInputBorder(), isDense: true,
            )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _filter<String>('Disciplina', materia, materias, (v) { setState(() => materia = v ?? ''); _search(reset: true); })),
            const SizedBox(width: 8),
            Expanded(child: _filter<String>('Banca', banca, bancas, (v) { setState(() => banca = v ?? ''); _search(reset: true); })),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _filter<int>('Ano', ano, anos, (v) { setState(() => ano = v ?? 0); _search(reset: true); }, label: (v) => v == 0 ? 'Todos' : '$v')),
            const SizedBox(width: 8),
            Expanded(child: _filter<String>('Dificuldade', nivel, niveis, (v) { setState(() => nivel = v ?? ''); _search(reset: true); }, label: _labelNivel)),
          ]),
          Row(children: [
            const Icon(Icons.sort, size: 18), const SizedBox(width: 6),
            const Text('Ordenar'), const SizedBox(width: 8),
            Expanded(child: DropdownButton<String>(isExpanded: true, value: ordem, items: const [
              DropdownMenuItem(value: 'recentes', child: Text('Mais recentes')),
              DropdownMenuItem(value: 'antigas', child: Text('Mais antigas')),
              DropdownMenuItem(value: 'aleatorias', child: Text('Aleatórias')),
            ], onChanged: (v) { if (v != null) { setState(() => ordem = v); _search(reset: true); } })),
            TextButton.icon(onPressed: _clear, icon: const Icon(Icons.restart_alt), label: const Text('Limpar')),
          ]),
        ]),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Row(children: [
        Expanded(child: Text('$total questões encontradas')),
        if (loading || loadingMore) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        IconButton(tooltip: 'Atualizar', onPressed: () => _search(reset: true), icon: const Icon(Icons.refresh)),
      ])),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, textAlign: TextAlign.center)),
      if (loading && questoes.isEmpty) const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (questoes.isEmpty && error == null) const Expanded(child: Center(child: Text('Nenhuma questão encontrada. Tente remover algum filtro.')))
      else Expanded(child: ListView(children: [
        for (final q in questoes) QCard(q),
        if (canLoadMore) Padding(padding: const EdgeInsets.all(16), child: OutlinedButton.icon(
          onPressed: loadingMore ? null : () => _search(reset: false),
          icon: const Icon(Icons.expand_more), label: Text(loadingMore ? 'Carregando…' : 'Carregar mais'),
        )),
      ])),
    ]);
  }

  Widget _filter<T>(String title, T current, List<T> options, ValueChanged<T?> onChanged,
      {String Function(T)? label}) {
    final T empty = (T == int ? 0 : '') as T;
    final values = <T>[empty, ...options.where((v) => v != empty)];
    final selected = values.contains(current) ? current : empty;
    return DropdownButtonFormField<T>(
      value: selected, isExpanded: true,
      decoration: InputDecoration(labelText: title, border: const OutlineInputBorder(), isDense: true),
      items: [for (final v in values) DropdownMenuItem<T>(
        value: v, child: Text(label != null ? label(v) : (v == empty ? 'Todos' : '$v'), overflow: TextOverflow.ellipsis),
      )],
      onChanged: onChanged,
    );
  }
}

class Simulado extends StatefulWidget {
  const Simulado({super.key});
  @override State<Simulado> createState() => _SimuladoState();
}
class _SimuladoState extends State<Simulado> {
  String nivel = 'medio';
  double quantidade = 20;
  List? questions;
  int correct = 0, answered = 0;
  bool loading = false;
  @override Widget build(BuildContext c) {
    if (questions == null) return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Monte seu simulado', style: Theme.of(c).textTheme.headlineSmall),
      const SizedBox(height: 12),
      SegmentedButton<String>(segments: const [
        ButtonSegment(value: 'facil', label: Text('Fácil')),
        ButtonSegment(value: 'medio', label: Text('Médio')),
        ButtonSegment(value: 'dificil', label: Text('Difícil')),
      ], selected: {nivel}, onSelectionChanged: (v) => setState(() => nivel = v.first)),
      Text('Quantidade de questões: ${quantidade.round()}'),
      Slider(value: quantidade, min: 10, max: 100, divisions: 9, onChanged: (v) => setState(() => quantidade = v)),
      FilledButton.icon(onPressed: loading ? null : () async {
        setState(() => loading = true);
        try {
          final r = await get('/simulado?nivel=$nivel&n=${quantidade.round()}');
          if (mounted) setState(() { questions = r as List; correct = 0; answered = 0; });
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('Erro ao montar simulado: $e')));
        } finally { if (mounted) setState(() => loading = false); }
      }, icon: const Icon(Icons.play_arrow), label: Text(loading ? 'Montando…' : 'Iniciar simulado')),
    ]);
    return Column(children: [
      ListTile(title: Text('Respondidas $answered/${questions!.length} · Acertos $correct'),
        trailing: TextButton(onPressed: () => setState(() => questions = null), child: const Text('Encerrar'))),
      Expanded(child: ListView(children: [for (final q in questions!) QCard(q, onAnswer: (ok) => setState(() {
        answered++; if (ok) correct++;
      }))])),
    ]);
  }
}
