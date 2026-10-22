import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const api = String.fromEnvironment('API', defaultValue: 'http://10.0.2.2:8000'); // troque pela URL https do servidor
String prov = 'gemini', key = '', model = '';
Map<String, String> hd() => {'Content-Type': 'application/json', 'X-IA-Provider': prov, 'X-IA-Key': key, 'X-IA-Model': model};
Future<dynamic> get(String p) async => api.isEmpty ? throw 'Servidor não configurado (falta a variável API_URL no GitHub)' : jsonDecode(utf8.decode((await http.get(Uri.parse('$api$p'), headers: hd())).bodyBytes));
Future<dynamic> post(String p, Map b) async => api.isEmpty ? throw 'Servidor não configurado (falta a variável API_URL no GitHub)' : jsonDecode(utf8.decode((await http.post(Uri.parse('$api$p'), headers: hd(), body: jsonEncode(b))).bodyBytes));

const provs = {'gemini': 'Google Gemini (grátis)', 'groq': 'Groq (grátis)', 'openrouter': 'OpenRouter (modelos grátis)', 'openai': 'ChatGPT / OpenAI', 'anthropic': 'Claude / Anthropic', 'deepseek': 'DeepSeek', 'mistral': 'Mistral'};
const links = {'gemini': 'aistudio.google.com/apikey', 'groq': 'console.groq.com/keys', 'openrouter': 'openrouter.ai/keys', 'openai': 'platform.openai.com/api-keys', 'anthropic': 'console.anthropic.com', 'deepseek': 'platform.deepseek.com', 'mistral': 'console.mistral.ai'};
void configIA(BuildContext c) {
  final kc = TextEditingController(text: key), mc = TextEditingController(text: model);
  showDialog(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    title: const Text('Sua IA'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(isExpanded: true, value: prov, items: [for (final e in provs.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => set(() => prov = v!)),
      Text('Entre em ${links[prov]} com sua conta Google ou e-mail, crie uma chave e cole abaixo.'),
      TextField(controller: kc, obscureText: true, decoration: const InputDecoration(labelText: 'Chave (API key)')),
      TextField(controller: mc, decoration: const InputDecoration(labelText: 'Modelo (opcional)'))])),
    actions: [TextButton(onPressed: () async {
      key = kc.text.trim(); model = mc.text.trim();
      final p = await SharedPreferences.getInstance(); p.setString('prov', prov); p.setString('key', key); p.setString('model', model);
      if (ctx.mounted) Navigator.pop(ctx);
    }, child: const Text('Salvar'))])));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (d) => Material(child: Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Text('Erro no app: ${d.exception}'))));
  try {
    final p = await SharedPreferences.getInstance();
    prov = p.getString('prov') ?? 'gemini'; key = p.getString('key') ?? ''; model = p.getString('model') ?? '';
  } catch (_) {}
  runApp(MaterialApp(
  title: 'Concursa', debugShowCheckedModeBanner: false,
  theme: ThemeData(colorSchemeSeed: const Color(0xFF3A3FD6), useMaterial3: true),
  darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF3A3FD6), brightness: Brightness.dark, useMaterial3: true),
  home: const Home()));
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _H(); }
class _H extends State<Home> {
  int i = 0;
  final tabs = const [Concursos(), Estudar(), QuestoesTela(), Simulado()];
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(['Concursos', 'Estudar', 'Questões', 'Simulados'][i]), actions: [IconButton(tooltip: 'Configurar IA', icon: const Icon(Icons.smart_toy_outlined), onPressed: () => configIA(c))]),
    body: SafeArea(child: tabs[i]),
    bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Concursos'),
      NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Estudar'),
      NavigationDestination(icon: Icon(Icons.edit_note), label: 'Questões'),
      NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Simulados')]));
}

class Concursos extends StatefulWidget { const Concursos({super.key}); @override State<Concursos> createState() => _C(); }
class _C extends State<Concursos> {
  String status = '', uf = '';
  @override Widget build(BuildContext c) => Column(children: [
    Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      for (final s in ['', 'aberto', 'previsto']) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s == '' ? 'Todos' : s), selected: status == s, onSelected: (_) => setState(() => status = s))),
      DropdownButton<String>(value: uf, items: ['', 'SP', 'MG', 'RJ', 'BA', 'RS', 'PR', 'PE', 'CE', 'DF'].map((u) => DropdownMenuItem(value: u, child: Text(u == '' ? 'Brasil' : u))).toList(), onChanged: (v) => setState(() => uf = v!))])),
    Expanded(child: FutureBuilder(future: get('/concursos?uf=$uf&status=$status'), builder: (_, s) {
      if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Não consegui conectar ao servidor. Se ele estava desligado, espere 1 minuto e volte.\n\n${s.error}')));
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final l = s.data as List; if (l.isEmpty) return const Center(child: Text('Nenhum concurso. Rode /coletar no servidor.'));
      return ListView(children: [for (final d in l) Card(child: ListTile(title: Text(d['titulo']), subtitle: Text('${d['uf']} · ${d['status']}'), trailing: Icon(d['status'] == 'aberto' ? Icons.check_circle : Icons.schedule)))]);
    }))]);
}

class Estudar extends StatefulWidget { const Estudar({super.key}); @override State<Estudar> createState() => _E(); }
class _E extends State<Estudar> {
  final t = TextEditingController(); String? out; bool load = false;
  @override Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
    TextField(controller: t, maxLines: 6, decoration: const InputDecoration(labelText: 'Conteúdo programático do edital', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    FilledButton(onPressed: load ? null : () async { setState(() => load = true); final r = await post('/apostila', {'conteudo': t.text}); setState(() { out = r['apostila']; load = false; }); }, child: Text(load ? 'Gerando… pode levar minutos' : 'Gerar apostila')),
    if (out != null) Padding(padding: const EdgeInsets.only(top: 16), child: SelectableText(out!))]);
}

class QCard extends StatefulWidget { final Map q; final void Function(bool)? onAnswer; const QCard(this.q, {this.onAnswer, super.key}); @override State<QCard> createState() => _Q(); }
class _Q extends State<QCard> {
  String? sel; List? com;
  @override Widget build(BuildContext c) { final q = widget.q;
    return Card(margin: const EdgeInsets.all(8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${q['banca']} · ${q['ano']} · ${q['materia']}', style: Theme.of(c).textTheme.bodySmall),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(q['enunciado'])),
      for (final a in q['alts']) ListTile(dense: true, title: Text('${a[0]}) ${a[1]}'),
        tileColor: sel == null ? null : a[0] == q['gabarito'] ? Colors.green.withOpacity(.2) : a[0] == sel ? Colors.red.withOpacity(.2) : null,
        onTap: sel != null ? null : () { setState(() => sel = a[0]); widget.onAnswer?.call(a[0] == q['gabarito']); }),
      if (sel != null) TextButton(onPressed: () async { final r = await get('/questoes/${q['id']}/comentarios'); setState(() => com = r); }, child: const Text('Ver comentários')),
      if (com != null) for (final m in com!) ListTile(dense: true, leading: Icon(m['tipo'] == 'ia' ? Icons.smart_toy : m['tipo'] == 'professor' ? Icons.school : Icons.person), title: Text(m['autor']), subtitle: Text(m['texto']))])));
  }
}

class QuestoesTela extends StatelessWidget { const QuestoesTela({super.key});
  @override Widget build(BuildContext c) => FutureBuilder(future: get('/questoes'), builder: (_, s) => s.hasError ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erro: ${s.error}'))) : !s.hasData ? const Center(child: CircularProgressIndicator()) : ListView(children: [for (final q in s.data as List) QCard(q)])); }

class Simulado extends StatefulWidget { const Simulado({super.key}); @override State<Simulado> createState() => _S(); }
class _S extends State<Simulado> {
  String nivel = 'medio'; double n = 20; List? qs; int acertos = 0, resp = 0;
  @override Widget build(BuildContext c) {
    if (qs == null) return ListView(padding: const EdgeInsets.all(16), children: [
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'facil', label: Text('Fácil')), ButtonSegment(value: 'medio', label: Text('Médio')), ButtonSegment(value: 'dificil', label: Text('Difícil'))], selected: {nivel}, onSelectionChanged: (v) => setState(() => nivel = v.first)),
      Text('Questões: ${n.round()}'), Slider(value: n, min: 10, max: 100, divisions: 9, onChanged: (v) => setState(() => n = v)),
      FilledButton(onPressed: () async { final r = await get('/simulado?nivel=$nivel&n=${n.round()}'); setState(() { qs = r; acertos = 0; resp = 0; }); }, child: const Text('Montar simulado'))]);
    return Column(children: [
      ListTile(title: Text('Respondidas $resp/${qs!.length} · Acertos $acertos'), trailing: TextButton(onPressed: () => setState(() => qs = null), child: const Text('Encerrar'))),
      Expanded(child: ListView(children: [for (final q in qs!) QCard(q, onAnswer: (ok) => setState(() { resp++; if (ok) acertos++; }))]))]);
  }
}
