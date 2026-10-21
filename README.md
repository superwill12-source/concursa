# Concursa – passo a passo (sem programar)

1. GITHUB: crie conta em github.com > "New repository" (nome: concursa) > "uploading an existing file" e arraste TODO o conteúdo desta pasta (inclusive a pasta .github). Clique em Commit.
2. SERVIDOR: crie conta em render.com (entre com o GitHub) > New > Blueprint > escolha o repositório > Apply. Copie o endereço https do serviço.
3. LIGAR O APP: no GitHub > Settings > Secrets and variables > Actions > aba Variables > New repository variable. Nome: API_URL  Valor: o endereço do passo 2 (sem "/" no final).
4. GERAR O APK: aba Actions > "Gerar APK" > Run workflow > espere ~8 min > baixe "concursa-apk" no fim da página, descompacte e instale.

## IA (cada pessoa usa a sua)
No app, toque no ícone do robô no topo, escolha a IA e cole sua chave. Para criar a chave, entre com sua conta Google ou e-mail:
- Google Gemini (grátis): aistudio.google.com/apikey
- Groq (grátis): console.groq.com/keys
- OpenRouter (modelos grátis): openrouter.ai/keys
- ChatGPT/OpenAI: platform.openai.com/api-keys
- Claude: console.anthropic.com
- DeepSeek: platform.deepseek.com
- Mistral: console.mistral.ai
