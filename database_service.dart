import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'question.dart';

class DatabaseService {
  DatabaseService._();
  static final instance=DatabaseService._();
  Database? _db;
  Future<void> init() async {
    final path=p.join(await getDatabasesPath(),'concursa.db');
    _db=await openDatabase(path,version:1,onCreate:(db,version) async {
      await db.execute('''CREATE TABLE questions(id INTEGER PRIMARY KEY AUTOINCREMENT,prompt TEXT NOT NULL,optionA TEXT NOT NULL,optionB TEXT NOT NULL,optionC TEXT NOT NULL,optionD TEXT NOT NULL,optionE TEXT NOT NULL,answer TEXT NOT NULL,explanation TEXT,subject TEXT,board TEXT,exam TEXT,year TEXT,difficulty TEXT,source TEXT,favorite INTEGER DEFAULT 0)''');
      await db.execute('''CREATE TABLE attempts(id INTEGER PRIMARY KEY AUTOINCREMENT,questionId INTEGER,chosen TEXT,correct INTEGER,createdAt TEXT)''');
      await db.execute('''CREATE TABLE sessions(id INTEGER PRIMARY KEY AUTOINCREMENT,total INTEGER,correct INTEGER,createdAt TEXT)''');
      final batch=db.batch();
      for(final q in demoQuestions){batch.insert('questions',q.toMap());}
      await batch.commit(noResult:true);
    });
  }
  Database get db { if(_db==null) throw StateError('Banco ainda não inicializado'); return _db!; }
  static final demoQuestions=<Question>[
    Question(prompt:'Qual princípio da Administração Pública exige atuação conforme a lei?',optionA:'Publicidade',optionB:'Legalidade',optionC:'Eficiência',optionD:'Impessoalidade',optionE:'Moralidade',answer:'B',explanation:'O princípio da legalidade determina que a Administração Pública atue conforme a lei e o ordenamento jurídico.',subject:'Direito Administrativo',board:'Exemplo didático',exam:'Questões demonstrativas',year:'2026',difficulty:'Fácil',source:'Exemplo didático'),
    Question(prompt:'Na língua portuguesa, qual classe de palavra normalmente caracteriza um substantivo?',optionA:'Verbo',optionB:'Preposição',optionC:'Adjetivo',optionD:'Conjunção',optionE:'Interjeição',answer:'C',explanation:'O adjetivo atribui característica ou qualidade a um substantivo.',subject:'Português',board:'Exemplo didático',exam:'Questões demonstrativas',year:'2026',difficulty:'Fácil',source:'Exemplo didático'),
    Question(prompt:'Qual é o resultado de 15% de 200?',optionA:'15',optionB:'20',optionC:'25',optionD:'30',optionE:'35',answer:'D',explanation:'10% de 200 é 20 e 5% é 10; portanto, 15% é 30.',subject:'Matemática',board:'Exemplo didático',exam:'Questões demonstrativas',year:'2026',difficulty:'Fácil',source:'Exemplo didático'),
    Question(prompt:'Qual órgão exerce tipicamente a função legislativa em um município brasileiro?',optionA:'Câmara Municipal',optionB:'Prefeitura',optionC:'Tribunal de Justiça',optionD:'Ministério Público',optionE:'Defensoria Pública',answer:'A',explanation:'A Câmara Municipal é o órgão legislativo municipal; a prefeitura exerce a função executiva.',subject:'Conhecimentos Gerais',board:'Exemplo didático',exam:'Questões demonstrativas',year:'2026',difficulty:'Média',source:'Exemplo didático'),
    Question(prompt:'Em informática, para que serve principalmente um navegador web?',optionA:'Editar hardware',optionB:'Acessar páginas e aplicações da web',optionC:'Substituir o sistema operacional',optionD:'Criar memória RAM',optionE:'Formatar automaticamente o computador',answer:'B',explanation:'Navegadores permitem acessar e interagir com páginas e aplicações na internet.',subject:'Informática',board:'Exemplo didático',exam:'Questões demonstrativas',year:'2026',difficulty:'Fácil',source:'Exemplo didático'),
  ];
  Future<List<Question>> list({String search='',String subject='Todas',String board='Todas',bool favoritesOnly=false,int limit=500}) async {
    final where=<String>[]; final args=<Object?>[];
    if(search.trim().isNotEmpty){where.add('(prompt LIKE ? OR subject LIKE ? OR board LIKE ? OR exam LIKE ?)'); final s='%${search.trim()}%'; args.addAll([s,s,s,s]);}
    if(subject!='Todas'){where.add('subject=?');args.add(subject);}
    if(board!='Todas'){where.add('board=?');args.add(board);}
    if(favoritesOnly) where.add('favorite=1');
    final rows=await db.query('questions',where:where.isEmpty?null:where.join(' AND '),whereArgs:args,orderBy:'id DESC',limit:limit);
    return rows.map(Question.fromMap).toList();
  }
  Future<List<String>> values(String col) async {final r=await db.rawQuery('SELECT DISTINCT $col FROM questions WHERE $col IS NOT NULL AND $col != "" ORDER BY $col'); return ['Todas',...r.map((e)=>e[col].toString())];}
  Future<void> toggleFavorite(Question q) async=>db.update('questions',{'favorite':q.favorite?0:1},where:'id=?',whereArgs:[q.id]);
  Future<void> recordAttempt(Question q,String chosen) async=>db.insert('attempts',{'questionId':q.id,'chosen':chosen,'correct':chosen==q.answer?1:0,'createdAt':DateTime.now().toIso8601String()});
  Future<void> recordSession(int total,int correct) async=>db.insert('sessions',{'total':total,'correct':correct,'createdAt':DateTime.now().toIso8601String()});
  Future<Map<String,int>> stats() async {
    final a=await db.rawQuery('SELECT COUNT(*) n, SUM(correct) c FROM attempts');
    final s=await db.rawQuery('SELECT COUNT(*) n FROM sessions');
    final q=await db.rawQuery('SELECT COUNT(*) n FROM questions');
    final f=await db.rawQuery('SELECT COUNT(*) n FROM questions WHERE favorite=1');
    return {'answered':(a.first['n'] as int?)??0,'correct':(a.first['c'] as int?)??0,'sessions':(s.first['n'] as int?)??0,'questions':(q.first['n'] as int?)??0,'favorites':(f.first['n'] as int?)??0};
  }
  Future<List<Map<String,Object?>>> recentAttempts() async=>db.rawQuery('SELECT attempts.*, questions.prompt FROM attempts LEFT JOIN questions ON questions.id=attempts.questionId ORDER BY attempts.id DESC LIMIT 30');
  Future<int> importJson(String text) async {
    final decoded=jsonDecode(text);
    if(decoded is! List) throw const FormatException('O JSON deve conter uma lista de questões.');
    var count=0;
    await db.transaction((txn) async {
      for(final item in decoded){
        if(item is! Map) continue;
        final m=Map<String,dynamic>.from(item);
        final prompt=(m['prompt']??m['question']??'').toString().trim();
        final answer=(m['answer']??'').toString().toUpperCase().trim();
        if(prompt.isEmpty || !['A','B','C','D','E'].contains(answer)) continue;
        final q=Question(prompt:prompt,optionA:'${m['optionA']??m['A']??''}',optionB:'${m['optionB']??m['B']??''}',optionC:'${m['optionC']??m['C']??''}',optionD:'${m['optionD']??m['D']??''}',optionE:'${m['optionE']??m['E']??''}',answer:answer,explanation:'${m['explanation']??''}',subject:'${m['subject']??'Geral'}',board:'${m['board']??'Não informada'}',exam:'${m['exam']??''}',year:'${m['year']??''}',difficulty:'${m['difficulty']??'Média'}',source:'${m['source']??'Importada pelo usuário'}');
        await txn.insert('questions',q.toMap()); count++;
      }
    });
    return count;
  }
  Future<String> exportJson() async {final rows=await db.query('questions'); return const JsonEncoder.withIndent('  ').convert(rows);}
}
