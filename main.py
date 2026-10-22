from urllib.parse import quote
import os, re, json, threading, random, sqlite3, feedparser, pdfplumber
from fastapi import Depends, Header, FastAPI, UploadFile, Form
from pydantic import BaseModel
import httpx, socket
socket.setdefaulttimeout(15)

app = FastAPI(title="Concursa")
db = sqlite3.connect("app.db", check_same_thread=False); db.row_factory = sqlite3.Row
db.executescript("""
create table if not exists concursos(id integer primary key, titulo, uf, status, link unique, data);
create table if not exists questoes(id integer primary key, banca, ano, materia, nivel, enunciado, alts, gabarito);
create table if not exists comentarios(id integer primary key, questao_id, autor, tipo, texto);""")
NOMES = {"AC":"Acre","AL":"Alagoas","AP":"Amapá","AM":"Amazonas","BA":"Bahia","CE":"Ceará","DF":"Distrito Federal","ES":"Espírito Santo","GO":"Goiás","MA":"Maranhão","MT":"Mato Grosso","MS":"Mato Grosso do Sul","MG":"Minas Gerais","PA":"Pará","PB":"Paraíba","PR":"Paraná","PE":"Pernambuco","PI":"Piauí","RJ":"Rio de Janeiro","RN":"Rio Grande do Norte","RS":"Rio Grande do Sul","RO":"Rondônia","RR":"Roraima","SC":"Santa Catarina","SP":"São Paulo","SE":"Sergipe","TO":"Tocantins"}
G = "https://news.google.com/rss/search?hl=pt-BR&gl=BR&ceid=BR:pt-419&q="
FEEDS = [("BR", G+"concurso+público+edital+inscrições"), ("BR", G+"concurso+público+previsto+autorizado")] + \
        [(u, G+quote(f"concurso público {n}")) for u, n in NOMES.items()]

def rows(q, a=()): return [dict(r) for r in db.execute(q, a)]
PROV = {  # provedor: (url, modelo padrão)
 "gemini": ("https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent", "gemini-2.5-flash"),
 "groq": ("https://api.groq.com/openai/v1/chat/completions", "llama-3.3-70b-versatile"),
 "openrouter": ("https://openrouter.ai/api/v1/chat/completions", "meta-llama/llama-3.3-70b-instruct:free"),
 "openai": ("https://api.openai.com/v1/chat/completions", "gpt-4o-mini"),
 "anthropic": ("https://api.anthropic.com/v1/messages", "claude-haiku-5-5"),
 "deepseek": ("https://api.deepseek.com/chat/completions", "deepseek-chat"),
 "mistral": ("https://api.mistral.ai/v1/chat/completions", "mistral-small-latest")}

def cfgia(x_ia_provider: str = Header("gemini"), x_ia_key: str = Header(""), x_ia_model: str = Header("")):
    return {"prov": x_ia_provider if x_ia_provider in PROV else "gemini", "key": x_ia_key.strip(), "model": x_ia_model.strip()}

def ia(prompt, cfg, max_tokens=3000):
    """Usa a IA e a chave de quem está usando o app (cada pessoa paga/usa a sua)."""
    if not cfg["key"]: return "Configure sua IA: toque no ícone do robô no topo do app e cole sua chave."
    url, padrao = PROV[cfg["prov"]]; m = cfg["model"] or padrao; k = cfg["key"]
    try:
        if cfg["prov"] == "gemini":
            r = httpx.post(url.format(m=m), headers={"x-goog-api-key": k}, timeout=120, json={"contents": [{"parts": [{"text": prompt}]}]}).json()
            return r["candidates"][0]["content"]["parts"][0]["text"]
        if cfg["prov"] == "anthropic":
            r = httpx.post(url, headers={"x-api-key": k, "anthropic-version": "2023-06-01"}, timeout=120, json={"model": m, "max_tokens": max_tokens, "messages": [{"role": "user", "content": prompt}]}).json()
            return r["content"][0]["text"]
        r = httpx.post(url, headers={"Authorization": f"Bearer {k}"}, timeout=120, json={"model": m, "max_tokens": max_tokens, "messages": [{"role": "user", "content": prompt}]}).json()
        return r["choices"][0]["message"]["content"]
    except Exception:
        return "Não consegui falar com a IA. Confira a chave, o modelo e se ainda há cota gratuita."

# ---------- 1. Coletor de concursos (abertos e previstos) ----------
def coletar_sync():
    novos = 0
    for uf0, url in FEEDS:
        try: itens = feedparser.parse(url).entries[:30]
        except Exception: continue
        for e in itens:
            t = f"{e.get('title','')} {e.get('summary','')}".lower()
            if "concurso" not in t and "edital" not in t: continue
            status = "previsto" if re.search(r"previst|autoriz|comiss[aã]o|banca|ser[aá] realizado|deve sair", t) else "aberto"
            uf = uf0 if uf0 != "BR" else next((u for u in NOMES if re.search(rf"\b{u}\b", e.get("title", ""))), "BR")
            try: db.execute("insert into concursos(titulo,uf,status,link,data) values(?,?,?,?,?)", (e.title, uf, status, e.link, e.get("published", ""))); novos += 1
            except sqlite3.IntegrityError: pass
    db.commit(); return {"novos": novos}

SEED = [("Exemplo",2024,"Português","facil","Assinale a frase com a concordância verbal correta.",[["A","Haviam muitos candidatos."],["B","Fazem dois anos que estudo."],["C","Houve muitos candidatos."],["D","Existe muitos candidatos."]],"C"),
("Exemplo",2024,"Raciocínio Lógico","medio","A negação de “todo aprovado estudou” é:",[["A","Nenhum aprovado estudou."],["B","Algum aprovado não estudou."],["C","Todo aprovado não estudou."],["D","Algum reprovado estudou."]],"B"),
("Exemplo",2024,"Direito Administrativo","medio","O princípio que exige que o administrador faça apenas o que a lei autoriza é o da:",[["A","Legalidade"],["B","Eficiência"],["C","Moralidade"],["D","Publicidade"]],"A"),
("Exemplo",2024,"Informática","facil","O atalho padrão para copiar um item selecionado no Windows é:",[["A","Ctrl+V"],["B","Ctrl+X"],["C","Ctrl+C"],["D","Ctrl+Z"]],"C"),
("Exemplo",2024,"Matemática","dificil","Se 3 operários fazem uma obra em 12 dias, 4 operários, no mesmo ritmo, farão em:",[["A","8 dias"],["B","9 dias"],["C","10 dias"],["D","16 dias"]],"B")]
if not rows("select 1 from questoes limit 1"):
    for b,a,m,n,e,al,g in SEED: db.execute("insert into questoes(banca,ano,materia,nivel,enunciado,alts,gabarito) values(?,?,?,?,?,?,?)",(b,a,m,n,e,json.dumps(al),g))
    db.commit()
@app.api_route("/coletar", methods=["GET", "POST"])
def coletar():
    threading.Thread(target=coletar_sync, daemon=True).start()
    return {"status": "busca iniciada; em 2 minutos recarregue o app"}

@app.on_event("startup")
def iniciar(): threading.Thread(target=coletar_sync, daemon=True).start()

@app.get("/concursos")
def concursos(uf: str = "", status: str = ""):
    return rows("select * from concursos where (?='' or uf=?) and (?='' or status=?) order by id desc limit 200", (uf, uf, status, status))

# ---------- 2. Provas anteriores: importa PDF oficial da banca ----------
@app.post("/provas/importar")
async def importar(arq: UploadFile, banca: str = Form(), ano: int = Form(), materia: str = Form(), nivel: str = Form("medio"), gabarito: str = Form("")):
    with pdfplumber.open(arq.file) as pdf: texto = "\n".join(p.extract_text() or "" for p in pdf.pages)
    blocos = re.split(r"\n\s*quest[aã]o\s+\d+\s*\n", texto, flags=re.I)[1:]
    n = 0
    for i, b in enumerate(blocos):
        alts = re.findall(r"^\(?([A-E])[\)\.]\s*(.+)$", b, flags=re.M)
        if len(alts) < 4: continue
        enun = re.split(r"^\(?A[\)\.]", b, flags=re.M)[0].strip()
        g = gabarito[i] if i < len(gabarito) else ""
        db.execute("insert into questoes(banca,ano,materia,nivel,enunciado,alts,gabarito) values(?,?,?,?,?,?,?)",
                   (banca, ano, materia, nivel, enun, json.dumps(alts), g.upper())); n += 1
    db.commit(); return {"importadas": n}

@app.get("/questoes")
def questoes(banca: str = "", materia: str = "", ano: int = 0, nivel: str = "", limit: int = 20):
    r = rows("""select * from questoes where (?='' or banca=?) and (?='' or materia=?) and (?=0 or ano=?) and (?='' or nivel=?)
                order by random() limit ?""", (banca, banca, materia, materia, ano, ano, nivel, nivel, limit))
    for q in r: q["alts"] = json.loads(q["alts"])
    return r

# ---------- 3. Comentários (IA + alunos + professores) ----------
@app.get("/questoes/{qid}/comentarios")
def comentarios(qid: int, cfg: dict = Depends(cfgia)):
    if cfg["key"] and not rows("select 1 from comentarios where questao_id=? and tipo='ia'", (qid,)):
        q = rows("select * from questoes where id=?", (qid,))[0]
        txt = ia(f"Comente esta questão de concurso, explique por que o gabarito {q['gabarito']} está certo e as demais erradas, cite a base legal quando houver:\n{q['enunciado']}\n{q['alts']}", cfg, 800)
        db.execute("insert into comentarios(questao_id,autor,tipo,texto) values(?,?,?,?)", (qid, "IA", "ia", txt)); db.commit()
    return rows("select * from comentarios where questao_id=?", (qid,))

class Com(BaseModel): autor: str; tipo: str = "aluno"; texto: str  # tipo: aluno | professor (professor exige verificação)
@app.post("/questoes/{qid}/comentarios")
def comentar(qid: int, c: Com):
    db.execute("insert into comentarios(questao_id,autor,tipo,texto) values(?,?,?,?)", (qid, c.autor, "aluno", c.texto)); db.commit(); return {"ok": True}

# ---------- 4. Simulados por nível de dificuldade ----------
@app.get("/simulado")
def simulado(banca: str = "", materia: str = "", nivel: str = "medio", n: int = 20): return questoes(banca, materia, 0, nivel, n)

# ---------- 5. Gerador de apostila a partir do edital ----------
class Edital(BaseModel): conteudo: str
@app.post("/apostila")
def apostila(e: Edital, cfg: dict = Depends(cfgia)):
    if not cfg["key"]: return {"topicos": [], "apostila": "Configure sua IA (ícone do robô no topo) para gerar apostilas."}
    topicos = json.loads(re.search(r"\[.*\]", ia(f"Divida este conteúdo programático em tópicos de estudo. Responda só um array JSON de strings:\n{e.conteudo}", cfg, 1500), re.S).group(0))
    caps = [f"# {t}\n" + ia(f"Escreva um capítulo completo de apostila para concurso sobre '{t}': teoria detalhada, quadro comparativo, exemplos, pegadinhas de banca, base legal citada e 5 exercícios com gabarito. Não invente leis.", cfg, 3500) for t in topicos[:12]]
    return {"topicos": topicos, "apostila": "\n\n".join(caps)}
