class Question {
  final int? id;
  final String prompt, optionA, optionB, optionC, optionD, optionE, answer, explanation, subject, board, exam, year, difficulty, source;
  final bool favorite;
  Question({this.id, required this.prompt, required this.optionA, required this.optionB, required this.optionC, required this.optionD, required this.optionE, required this.answer, required this.explanation, required this.subject, required this.board, required this.exam, required this.year, required this.difficulty, required this.source, this.favorite=false});
  factory Question.fromMap(Map<String,dynamic> m)=>Question(
    id:m['id'] as int?, prompt:(m['prompt']??'').toString(), optionA:(m['optionA']??'').toString(),
    optionB:(m['optionB']??'').toString(), optionC:(m['optionC']??'').toString(), optionD:(m['optionD']??'').toString(),
    optionE:(m['optionE']??'').toString(), answer:(m['answer']??'A').toString().toUpperCase(),
    explanation:(m['explanation']??'').toString(), subject:(m['subject']??'Geral').toString(),
    board:(m['board']??'Não informada').toString(), exam:(m['exam']??'').toString(), year:(m['year']??'').toString(),
    difficulty:(m['difficulty']??'Média').toString(), source:(m['source']??'Questão adicionada pelo usuário').toString(),
    favorite:(m['favorite']??0)==1 || m['favorite']==true);
  Map<String,dynamic> toMap()=>{'prompt':prompt,'optionA':optionA,'optionB':optionB,'optionC':optionC,'optionD':optionD,'optionE':optionE,'answer':answer,'explanation':explanation,'subject':subject,'board':board,'exam':exam,'year':year,'difficulty':difficulty,'source':source,'favorite':favorite?1:0};
  List<String> get options=>[optionA,optionB,optionC,optionD,optionE];
}
