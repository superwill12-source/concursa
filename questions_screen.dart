import 'package:flutter/material.dart';
import 'question.dart';
import 'database_service.dart';
import 'main.dart';
class QuestionsScreen extends StatefulWidget {const QuestionsScreen({super.key}); @override State<QuestionsScreen> createState()=>_QuestionsScreenState();}
class _QuestionsScreenState extends State<QuestionsScreen>{
final search=TextEditingController(); String subject='Todas',board='Todas'; bool favorites=false; List<Question> items=[]; List<String> subjects=['Todas'],boards=['Todas']; bool loading=true;
@override void initState(){super.initState();refresh();}
Future<void> refresh()async{final s=await DatabaseService.instance.values('subject');final b=await DatabaseService.instance.values('board');final q=await DatabaseService.instance.list(search:search.text,subject:subject,board:board,favoritesOnly:favorites);if(mounted)setState((){subjects=s;boards=b;items=q;loading=false;});}
@override void dispose(){search.dispose();super.dispose();}
@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Banco de questões'),actions:[IconButton(tooltip:'Só favoritas',onPressed:(){setState(()=>favorites=!favorites);refresh();},icon:Icon(favorites?Icons.star:Icons.star_border,color:favorites?lime:null))]),body:Column(children:[
Padding(padding:const EdgeInsets.fromLTRB(16,8,16,4),child:TextField(controller:search,onChanged:(_)=>refresh(),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar questão, assunto, banca...'))),
Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:5),child:Row(children:[Expanded(child:DropdownButtonFormField<String>(value:subject,decoration:const InputDecoration(labelText:'Assunto'),items:subjects.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null){setState(()=>subject=v);refresh();}})),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:board,decoration:const InputDecoration(labelText:'Banca'),items:boards.map((v)=>DropdownMenuItem(value:v,child:Text(v,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null){setState(()=>board=v);refresh();}}))])),
Expanded(child:loading?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('Nenhuma questão encontrada.')):ListView.builder(padding:const EdgeInsets.all(12),itemCount:items.length,itemBuilder:(c,i)=>QuestionTile(question:items[i],onChanged:refresh)))
]));}
class QuestionTile extends StatelessWidget{final Question question;final VoidCallback onChanged;const QuestionTile({super.key,required this.question,required this.onChanged});
@override Widget build(BuildContext context)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(14),title:Text(question.prompt,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Padding(padding:const EdgeInsets.only(top:8),child:Text('${question.subject} • ${question.board} • ${question.difficulty}')),trailing:IconButton(icon:Icon(question.favorite?Icons.star:Icons.star_border,color:question.favorite?lime:null),onPressed:()async{await DatabaseService.instance.toggleFavorite(question);onChanged();}),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>QuestionDetail(question:question))).then((_)=>onChanged())));}
class QuestionDetail extends StatefulWidget {
  final Question question;
  const QuestionDetail({super.key, required this.question});

  @override
  State<QuestionDetail> createState() => _QuestionDetailState();
}

class _QuestionDetailState extends State<QuestionDetail> {
  String? chosen;
  bool checked = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    const letters = ['A', 'B', 'C', 'D', 'E'];

    return Scaffold(
      appBar: AppBar(title: const Text('Resolver questão')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            q.subject.toUpperCase(),
            style: const TextStyle(color: lime, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            q.prompt,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (i) {
            if (q.options[i].trim().isEmpty) {
              return const SizedBox.shrink();
            }
            final letter = letters[i];
            final isCorrect = checked && letter == q.answer;
            final isWrong = checked && letter == chosen && letter != q.answer;
            return Card(
              color: isCorrect
                  ? Colors.green.withValues(alpha: .2)
                  : isWrong
                      ? Colors.red.withValues(alpha: .2)
                      : null,
              child: RadioListTile<String>(
                value: letter,
                groupValue: chosen,
                title: Text('$letter) ${q.options[i]}'),
                onChanged: checked ? null : (v) => setState(() => chosen = v),
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: chosen == null || checked
                ? null
                : () async {
                    await DatabaseService.instance.recordAttempt(q, chosen!);
                    setState(() => checked = true);
                  },
            child: const Text('Confirmar resposta'),
          ),
          if (checked) ...[
            const SizedBox(height: 12),
            Text(
              chosen == q.answer
                  ? 'Resposta correta!'
                  : 'Resposta incorreta. Gabarito: ${q.answer}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: chosen == q.answer
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
            ),
            if (q.explanation.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('Explicação: ${q.explanation}'),
                ),
              ),
            Text(
              'Fonte: ${q.source}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
