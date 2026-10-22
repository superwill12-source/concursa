# Concursa — arquivos na raiz

Todos os arquivos Dart ficam diretamente na raiz do repositório para facilitar edição pelo celular.

Arquivos: `main.dart`, `question.dart`, `database_service.dart`, `home_screen.dart`, `questions_screen.dart`, `simulado_screen.dart`, `import_screen.dart`, `progress_screen.dart`, `pubspec.yaml` e `apk.yml`.

## GitHub Actions
Para o GitHub reconhecer o workflow automaticamente, o arquivo `apk.yml` precisa estar em `.github/workflows/apk.yml`. Essa pasta é exigida pelo GitHub Actions; o código Dart e o pubspec podem continuar na raiz. O workflow cria a pasta `app` apenas temporariamente no ambiente de compilação, não no repositório.

## Conteúdo
As questões iniciais são exemplos didáticos. A importação aceita JSON; o app não extrai automaticamente PDFs do PCI Concursos. Importe apenas conteúdo que tenha permissão de uso.
