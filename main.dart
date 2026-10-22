import 'package:flutter/material.dart';
import 'database_service.dart';
import 'home_screen.dart';
import 'questions_screen.dart';
import 'simulado_screen.dart';
import 'import_screen.dart';
import 'progress_screen.dart';

const lime = Color(0xFFB7F34A);
final appTabIndex = ValueNotifier<int>(0);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const ConcursaApp());
}
class ConcursaApp extends StatelessWidget {
  const ConcursaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Concursa', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF10120F),
      colorScheme: ColorScheme.fromSeed(seedColor: lime, brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF10120F), foregroundColor: Colors.white),
      cardTheme: CardThemeData(color: const Color(0xFF1B1F19), elevation: 0),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1B1F19),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
    ),
    home: const AppShell(),
  );
}
class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState()=>_AppShellState(); }
class _AppShellState extends State<AppShell> {
  int index=0;
  @override void initState(){super.initState(); appTabIndex.addListener(_syncTab);}
  void _syncTab(){if(mounted)setState(()=>index=appTabIndex.value);}
  @override void dispose(){appTabIndex.removeListener(_syncTab);super.dispose();}
  final pages = const [HomeScreen(), QuestionsScreen(), SimuladoScreen(), ProgressScreen(), ImportScreen()];
  final labels = const ['Início','Questões','Simulado','Progresso','Importar'];
  final icons = const [Icons.home_rounded,Icons.library_books_rounded,Icons.quiz_rounded,Icons.insights_rounded,Icons.file_upload_rounded];
  @override Widget build(BuildContext context)=>Scaffold(
    body: IndexedStack(index:index, children: pages),
    bottomNavigationBar: NavigationBar(selectedIndex:index, onDestinationSelected:(v){appTabIndex.value=v;setState(()=>index=v);},
      destinations: List.generate(labels.length,(i)=>NavigationDestination(icon:Icon(icons[i]),label:labels[i]))),
  );
}
