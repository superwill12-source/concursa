import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const ConcursaApp());

const lime = Color(0xFFB7F34A);
const bg = Color(0xFF0D1110);
const panel = Color(0xFF171D1A);

class ConcursaApp extends StatelessWidget {
  const ConcursaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Concursa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lime,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> openPage(String address) async {
    final uri = Uri.parse(address);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o site. Verifique sua internet.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: lime, size: 27),
            SizedBox(width: 9),
            Text('Concursa', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: lime.withOpacity(.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'GRÁTIS',
                  style: TextStyle(color: lime, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25321F), Color(0xFF171D1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: lime.withOpacity(.25)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUA PRÓXIMA APROVAÇÃO COMEÇA AQUI',
                    style: TextStyle(color: lime, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('Estude com provas anteriores',
                    style: TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w800)),
                  SizedBox(height: 9),
                  Text('Encontre provas gratuitas no PCI Concursos e baixe os PDFs pelo navegador do celular.',
                    style: TextStyle(color: Colors.white70, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('ENCONTRE SUA PROVA',
              style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ActionCard(
              icon: Icons.picture_as_pdf_rounded,
              title: 'Provas anteriores',
              subtitle: 'Pesquisar provas e baixar arquivos PDF',
              onTap: () => openPage('https://www.pciconcursos.com.br/provas/'),
            ),
            const SizedBox(height: 12),
            ActionCard(
              icon: Icons.quiz_rounded,
              title: 'Simulados gratuitos',
              subtitle: 'Treinar questões diretamente no PCI',
              onTap: () => openPage('https://www.pciconcursos.com.br/simulados/'),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.download_for_offline_rounded, color: lime),
                    SizedBox(width: 9),
                    Text('Como guardar uma prova offline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  SizedBox(height: 12),
                  StepText(number: '1', text: 'Toque em “Provas anteriores” e escolha o concurso.'),
                  StepText(number: '2', text: 'Abra o PDF da prova e use o botão de baixar do navegador.'),
                  StepText(number: '3', text: 'Depois, abra o PDF pela pasta Downloads do celular, mesmo sem internet.'),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'O Concursa abre o catálogo público do PCI; o download de cada arquivo é feito pelo próprio site/navegador. Este app não baixa todo o acervo automaticamente.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lime.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: lime, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: Colors.white54, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class StepText extends StatelessWidget {
  final String number;
  final String text;

  const StepText({super.key, required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: bg, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.4))),
        ],
      ),
    );
  }
}
