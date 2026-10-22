import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const api = String.fromEnvironment(
  'API',
  defaultValue: 'http://10.0.2.2:8000',
);
const _cacheKey = 'concursa_questoes_cache_v1';

String prov = 'gemini', key = '', model = '';

Map<String, String> hd() => {
  'Content-Type': 'application/json',
  'X-IA-Provider': prov,
  'X-IA-Key': key,
  'X-IA-Model': model,
};

Future<dynamic> get(String p) async {
  if (api.isEmpty) throw Exception('Servidor não configurado.');
  final r = await http
      .get(Uri.parse('$api$p'), headers: hd())
      .timeout(const Duration(seconds: 12));
  if (r.statusCode < 200 || r.statusCode >= 300) {
    throw Exception('Servidor respondeu HTTP ${r.statusCode}.');
  }
  return jsonDecode(utf8.decode(r.bodyBytes));
}

Future<dynamic> post(String p, Map b) async {
  if (api.isEmpty) throw Exception('Servidor não configurado.');
  final r = await http
      .post(Uri.parse('$api$p'), headers: hd(), body: jsonEncode(b))
      .timeout(const Duration(seconds: 120));
  if (r.statusCode < 200 || r.statusCode >= 300) {
    throw Exception('Servidor respondeu HTTP ${r.statusCode}.');
  }
  return jsonDecode(utf8.decode(r.bodyBytes));
}

// Questões de exemplo incorporadas no APK. O banco online substitui/atualiza
// esse conjunto quando há conexão. Não são questões oficiais de provas.
final List<Map<String, dynamic>> _questoesBasicas = [
  {
    'id': -1, 'banca': 'Concursa', 'ano': 2026, 'materia': 'Português',
    'nivel': 'facil',
    'enunciado': 'Assinale a frase com concordância verbal correta.',
    'alts': [
      ['A', 'Haviam muitos candidatos.'],
      ['B', 'Fazem dois anos que estudo.'],
      ['C', 'Houve muitos candidatos.'],
      ['D', 'Existe muitos candidatos.'],
    ],
    'gabarito': 'C',
  },
  {
    'id': -2, 'banca': 'Concursa', 'ano': 2026, 'materia': 'Raciocínio Lógico',
    'nivel': 'medio',
    'enunciado': 'A negação de “todo aprovado estudou” é:',
    'alts': [
      ['A', 'Nenhum aprovado estudou.'],
      ['B', 'Algum aprovado não estudou.'],
      ['C', 'Todo aprovado não estudou.'],
      ['D', 'Algum reprovado estudou.'],
    ],
    'gabarito': 'B',
  },
  {
    'id': -3, 'banca': 'Concursa', 'ano': 2026, 'materia': 'Direito Administrativo',
    'nivel': 'medio',
    'enunciado': 'O princípio que exige que o administrador faça apenas o que a lei autoriza é o da:',
    'alts': [
      ['A', 'Legalidade'], ['B', 'Eficiência'],
      ['C', 'Moralidade'], ['D', 'Publicidade'],
    ],
    'gabarito': 'A',
  },
  {
    'id': -4, 'banca': 'Concursa', 'ano': 2026, 'materia': 'Informática',
    'nivel': 'facil',
    'enunciado': 'No Windows, qual atalho normalmente copia um item selecionado?',
    'alts': [
      ['A', 'Ctrl+V'], ['B', 'Ctrl+X'],
      ['C', 'Ctrl+C'], ['D', 'Ctrl+Z'],
    ],
    'gabarito': 'C',
  },
  {
    'id': -5, 'banca': 'Concursa', 'ano': 2026, 'materia': 'Matemática',
    'nivel': 'medio',
    'enunciado': 'Se 3 trabalhadores fazem um serviço em 12 dias, quantos dias levariam 4 trabalhadores no mesmo ritmo?',
    'alts': [
      ['A', '6 dias'], ['B', '8 dias'],
      ['C', '9 dias'], ['D', '16 dias'],
    ],
    'gabarito': 'B',
  },
];

// Tenta atualizar pela internet. Se falhar, usa o último banco salvo no celular.
// Se nunca houve conexão, usa as questões básicas incluídas no APK.
Future<List<Map<String, dynamic>>> carregarQuestoes() async {
  final prefs = await SharedPreferences.getInstance();

  try {
    final resposta = await get('/questoes?limit=500');
    if (resposta is List && resposta.isNotEmpty) {
      final lista = resposta
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await prefs.setString(_cacheKey, jsonEncode(lista));
      return lista;
    }
  } catch (_) {
    // Sem internet/servidor indisponível: tenta o cache local abaixo.
  }

  final salvo = prefs.getString(_cacheKey);
  if (salvo != null && salvo.isNotEmpty) {
    try {
      final decoded = jsonDecode(salvo) as List;
      if (decoded.isNotEmpty) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      // Cache inválido: usa as questões incorporadas no APK.
    }
  }
  return _questoesBasicas.map((q) => Map<String, dynamic>.from(q)).toList();
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
  showDialog(
    context: c,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Sua IA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: prov,
                items: [
                  for (final e in provs.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => set(() => prov = v!),
              ),
              Text('Entre em ${links[prov]} com sua conta e crie uma chave.'),
              TextField(
                controller: kc,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Chave (API key)'),
              ),
              TextField(
                controller: mc,
                decoration: const InputDecoration(labelText: 'Modelo (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              key = kc.text.trim();
              model = mc.text.trim();
              final p = await SharedPreferences.getInstance();
              await p.setString('prov', prov);
              await p.setString('key', key);
              await p.setString('model', model);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (d) => Material(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(child: Text('Erro no app: ${d.exception}')),
    ),
  );
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
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF3A3FD6),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: const Home(),
  ));
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _H();
}

class _H extends State<Home> {
  int i = 0;
  final tabs = const [Concursos(), Estudar(), QuestoesTela(), Simulado()];

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(['Concursos', 'Estudar', 'Questões', 'Simulados'][i]),
      actions: [
        IconButton(
          tooltip: 'Configurar IA',
          icon: const Icon(Icons.smart_toy_outlined),
          onPressed: () => configIA(c),
        ),
      ],
    ),
    body: SafeArea(child: tabs[i]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: i,
      onDestinationSelected: (v) => setState(() => i = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Concursos'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Estudar'),
        NavigationDestination(icon: Icon(Icons.edit_note), label: 'Questões'),
        NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Simulados'),
      ],
    ),
  );
}

class Concursos extends StatefulWidget {
  const Concursos({super.key});
  @override
  State<Concursos> createState() => _C();
}

class _C extends State<Concursos> {
  String status = '', uf = '';

  @override
  Widget build(BuildContext c) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        for (final s in ['', 'aberto', 'previsto'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s == '' ? 'Todos' : s),
              selected: status == s,
              onSelected: (_) => setState(() => status = s),
            ),
          ),
        DropdownButton<String>(
          value: uf,
          items: ['', 'SP', 'MG', 'RJ', 'BA', 'RS', 'PR', 'PE', 'CE', 'DF']
              .map((u) => DropdownMenuItem(value: u, child: Text(u == '' ? 'Brasil' : u)))
              .toList(),
          onChanged: (v) => setState(() => uf = v!),
        ),
      ]),
    ),
    Expanded(
      child: FutureBuilder(
        future: get('/concursos?uf=$uf&status=$status'),
        builder: (_, s) {
          if (s.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Não consegui conectar ao servidor. Notícias de concursos precisam de internet.'),
              ),
            );
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final l = s.data as List;
          if (l.isEmpty) return const Center(child: Text('Nenhum concurso encontrado.'));
          return ListView(children: [
            for (final d in l)
              Card(
                child: ListTile(
                  title: Text(d['titulo']),
                  subtitle: Text('${d['uf']} · ${d['status']}\nToque para abrir a notícia'),
                  isThreeLine: true,
                  trailing: Icon(d['status'] == 'aberto' ? Icons.check_circle : Icons.schedule),
                  onTap: () => launchUrl(
                    Uri.parse(d['link']),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
          ]);
        },
      ),
    ),
  ]);
}

class Estudar extends StatefulWidget {
  const Estudar({super.key});
  @override
  State<Estudar> createState() => _E();
}

class _E extends State<Estudar> {
  final t = TextEditingController();
  String? out;
  bool load = false;

  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        controller: t,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Conteúdo programático do edital',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: load ? null : () async {
          setState(() => load = true);
          try {
            final r = await post('/apostila', {'conteudo': t.text});
            if (mounted) setState(() => out = r['apostila']?.toString());
          } catch (e) {
            if (mounted) setState(() => out = 'Para gerar apostilas, conecte-se à internet e verifique o servidor/IA.\n$e');
          } finally {
            if (mounted) setState(() => load = false);
          }
        },
        child: Text(load ? 'Gerando… pode levar minutos' : 'Gerar apostila'),
      ),
      if (out != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SelectableText(out!),
        ),
    ],
  );
}

class QCard extends StatefulWidget {
  final Map q;
  final void Function(bool)? onAnswer;
  const QCard(this.q, {this.onAnswer, super.key});
  @override
  State<QCard> createState() => _Q();
}

class _Q extends State<QCard> {
  String? sel;
  List? com;

  @override
  Widget build(BuildContext c) {
    final q = widget.q;
    final alts = (q['alts'] as List? ?? const []);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${q['banca'] ?? 'Banco local'} · ${q['ano'] ?? ''} · ${q['materia'] ?? ''}',
              style: Theme.of(c).textTheme.bodySmall,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('${q['enunciado'] ?? ''}'),
            ),
            for (final a in alts)
              ListTile(
                dense: true,
                title: Text('${a[0]}) ${a[1]}'),
                tileColor: sel == null
                    ? null
                    : a[0] == q['gabarito']
                        ? Colors.green.withOpacity(.2)
                        : a[0] == sel
                            ? Colors.red.withOpacity(.2)
                            : null,
                onTap: sel != null
                    ? null
                    : () {
                        setState(() => sel = '${a[0]}');
                        widget.onAnswer?.call('${a[0]}' == '${q['gabarito']}');
                      },
              ),
            if (sel != null && (q['id'] as int? ?? 0) > 0)
              TextButton(
                onPressed: () async {
                  try {
                    final r = await get('/questoes/${q['id']}/comentarios');
                    if (mounted) setState(() => com = r as List);
                  } catch (_) {
                    if (mounted) {
                      setState(() => com = [
                        {'autor': 'Modo offline', 'tipo': 'sistema', 'texto': 'Comentários precisam de conexão. A questão e o gabarito continuam disponíveis offline.'}
                      ]);
                    }
                  }
                },
                child: const Text('Ver comentários'),
              ),
            if (com != null)
              for (final m in com!)
                ListTile(
                  dense: true,
                  leading: Icon(
                    m['tipo'] == 'ia'
                        ? Icons.smart_toy
                        : m['tipo'] == 'professor'
                            ? Icons.school
                            : Icons.person,
                  ),
                  title: Text('${m['autor']}'),
                  subtitle: Text('${m['texto']}'),
                ),
          ],
        ),
      ),
    );
  }
}

class QuestoesTela extends StatefulWidget {
  const QuestoesTela({super.key});
  @override
  State<QuestoesTela> createState() => _QuestoesTelaState();
}

class _QuestoesTelaState extends State<QuestoesTela> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = carregarQuestoes();
  }

  Future<void> atualizar() async {
    setState(() => future = carregarQuestoes());
    await future;
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (_, s) {
      if (!s.hasData && s.hasError) {
        return Center(child: Text('Não foi possível carregar questões: ${s.error}'));
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final lista = s.data!;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Expanded(child: Text('${lista.length} questões disponíveis (online/offline)')),
            IconButton(
              tooltip: 'Atualizar banco',
              onPressed: atualizar,
              icon: const Icon(Icons.sync),
            ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: atualizar,
            child: ListView(
              children: [for (final q in lista) QCard(q)],
            ),
          ),
        ),
      ]);
    },
  );
}

class Simulado extends StatefulWidget {
  const Simulado({super.key});
  @override
  State<Simulado> createState() => _S();
}

class _S extends State<Simulado> {
  String nivel = 'medio';
  double n = 20;
  List<Map<String, dynamic>>? qs;
  int acertos = 0, resp = 0;
  bool carregando = false;

  @override
  Widget build(BuildContext c) {
    if (qs == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'facil', label: Text('Fácil')),
              ButtonSegment(value: 'medio', label: Text('Médio')),
              ButtonSegment(value: 'dificil', label: Text('Difícil')),
            ],
            selected: {nivel},
            onSelectionChanged: (v) => setState(() => nivel = v.first),
          ),
          Text('Questões: ${n.round()}'),
          Slider(value: n, min: 10, max: 100, divisions: 9, onChanged: (v) => setState(() => n = v)),
          FilledButton(
            onPressed: carregando ? null : () async {
              setState(() => carregando = true);
              try {
                final todas = await carregarQuestoes();
                var candidatas = todas.where((q) => '${q['nivel'] ?? ''}' == nivel).toList();
                if (candidatas.isEmpty) candidatas = List<Map<String, dynamic>>.from(todas);
                candidatas.shuffle(Random());
                final escolhidas = candidatas.take(n.round()).toList();
                if (mounted) setState(() {
                  qs = escolhidas;
                  acertos = 0;
                  resp = 0;
                });
              } finally {
                if (mounted) setState(() => carregando = false);
              }
            },
            child: Text(carregando ? 'Carregando banco…' : 'Montar simulado'),
          ),
          const SizedBox(height: 8),
          const Text('O simulado usa as questões baixadas anteriormente e continua funcionando sem internet.'),
        ],
      );
    }

    return Column(children: [
      ListTile(
        title: Text('Respondidas $resp/${qs!.length} · Acertos $acertos'),
        trailing: TextButton(
          onPressed: () => setState(() => qs = null),
          child: const Text('Encerrar'),
        ),
      ),
      Expanded(
        child: ListView(
          children: [
            for (final q in qs!)
              QCard(q, onAnswer: (ok) => setState(() {
                resp++;
                if (ok) acertos++;
              })),
          ],
        ),
      ),
    ]);
  }
}
