from urllib.parse import quote
import os, re, json, time, threading, random, sqlite3, feedparser, pdfplumber
from fastapi import Depends, Header, FastAPI, UploadFile, Form, HTTPException
from pydantic import BaseModel
import httpx, socket

socket.setdefaulttimeout(15)
app = FastAPI(title="Concursa")
db = sqlite3.connect("app.db", check_same_thread=False)
db.row_factory = sqlite3.Row
db.executescript("""
create table if not exists concursos(id integer primary key, titulo, uf, status, link unique, data);
create table if not exists questoes(id integer primary key, banca, ano, materia, nivel, enunciado, alts, gabarito);
create table if not exists comentarios(id integer primary key, questao_id, autor, tipo, texto);
""")
NOMES = {"AC":"Acre","AL":"Alagoas","AP":"Amapá","AM":"Amazonas","BA":"Bahia","CE":"Ceará","DF":"Distrito Federal","ES":"Espírito Santo","GO":"Goiás","MA":"Maranhão","MT":"Mato Grosso","MS":"Mato Grosso do Sul","MG":"Minas Gerais","PA":"Pará","PB":"Paraíba","PR":"Paraná","PE":"Pernambuco","PI":"Piauí","RJ":"Rio de Janeiro","RN":"Rio Grande do Norte","RS":"Rio Grande do Sul","RO":"Rondônia","RR":"Roraima","SC":"Santa Catarina","SP":"São Paulo","SE":"Sergipe","TO":"Tocantins"}
G = "https://news.google.com/rss/search?hl=pt-BR&gl=BR&ceid=BR:pt-419&q="
B = "https://www.bing.com/news/search?format=rss&mkt=pt-BR&q="
SITES = [
    ("BR", "https://blog.grancursosonline.com.br/feed/"),
    ("BR", "https://www.estrategiaconcursos.com.br/blog/feed/"),
    ("BR", "https://www.pciconcursos.com.br/rss"),
    ("BR", "https://www.concursosnobrasil.com.br/feed/"),
]
FEEDS = list(SITES)
for uf, nome in [("BR", "Brasil")] + list(NOMES.items()):
    termo = "concurso público" if uf == "BR" else f"concurso público {nome}"
    FEEDS.append((uf, B + quote(termo + " edital inscrições")))
    FEEDS.append((uf, G + quote(termo)))
FEEDS.append(("BR", B + quote("concurso público previsto autorizado")))

def rows(q, a=()):
    return [dict(r) for r in db.execute(q, a)]

PROV = {
    "gemini": ("https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent", "gemini-3.1-flash-lite"),
    "groq": ("https://api.groq.com/openai/v1/chat/completions", "llama-3.3-70b-versatile"),
    "openrouter": ("https://openrouter.ai/api/v1/chat/completions", "meta-llama/llama-3.3-70b-instruct:free"),
    "openai": ("https://api.openai.com/v1/chat/completions", "gpt-4o-mini"),
    "anthropic": ("https://api.anthropic.com/v1/messages", "claude-haiku-5-5"),
    "deepseek": ("https://api.deepseek.com/chat/completions", "deepseek-chat"),
    "mistral": ("https://api.mistral.ai/v1/chat/completions", "mistral-small-latest"),
}

def cfgia(x_ia_provider: str = Header("gemini"), x_ia_key: str = Header(""), x_ia_model: str = Header("")):
    return {
        "prov": x_ia_provider if x_ia_provider in PROV else "gemini",
        "key": x_ia_key.strip(),
        "model": x_ia_model.strip(),
    }

GEMINI_FALLBACK = ["gemini-3.1-flash-lite", "gemini-2.5-flash", "gemini-flash-latest"]

def ia(prompt, cfg, max_tokens=3000):
    """Devolve (texto, None) em sucesso ou (None, mensagem_de_erro) em falha."""
    if not cfg["key"]:
        return None, "Configure sua IA: toque no ícone do robô no topo do app e cole sua chave."
    url, padrao = PROV[cfg["prov"]]
    k = cfg["key"]
    m = re.sub(r"^models/", "", (cfg["model"] or "").strip())
    valido = r"[A-Za-z0-9.\-]+" if cfg["prov"] == "gemini" else r"[A-Za-z0-9._:/\-]+"
    modelo_valido = bool(m) and bool(re.fullmatch(valido, m))
    if not modelo_valido:
        m = padrao
    try:
        if cfg["prov"] == "gemini":
            cands = [m] if modelo_valido else [m] + [x for x in GEMINI_FALLBACK if x != m]
            for m in cands:
                for tentativa in range(3):
                    resp = httpx.post(
                        url.format(m=m),
                        headers={"x-goog-api-key": k},
                        timeout=120,
                        json={"contents": [{"role": "user", "parts": [{"text": prompt}]}],
                              "generationConfig": {"maxOutputTokens": 8192, "temperature": 0.4}},
                    )
                    if resp.status_code not in (429, 500, 503):
                        break
                    time.sleep(4 * (tentativa + 1))
                if resp.status_code not in (400, 404, 429, 500, 503):
                    break
        elif cfg["prov"] == "anthropic":
            resp = httpx.post(url, headers={"x-api-key": k, "anthropic-version": "2023-06-01"},
                              timeout=120, json={"model": m, "max_tokens": max_tokens,
                              "messages": [{"role": "user", "content": prompt}]})
        else:
            resp = httpx.post(url, headers={"Authorization": f"Bearer {k}"}, timeout=120,
                              json={"model": m, "max_tokens": max_tokens,
                                    "messages": [{"role": "user", "content": prompt}]})
        r = resp.json() if resp.content else {}
        if resp.status_code >= 400 or "error" in r:
            return None, f"A IA {cfg['prov']} (modelo {m}) recusou o pedido (código {resp.status_code}): {str(r.get('error', r))[:300]}"
        if cfg["prov"] == "gemini":
            cand = (r.get("candidates") or [{}])[0]
            partes = (cand.get("content") or {}).get("parts") or []
            texto = "".join(p.get("text", "") for p in partes if not p.get("thought")).strip()
            if not texto:
                motivo = cand.get("finishReason") or r.get("promptFeedback", {}).get("blockReason") or "desconhecido"
                return None, f"O Gemini ({m}) não devolveu texto. Motivo: {motivo}. Tente de novo ou reduza o conteúdo do edital."
            return texto, None
        if cfg["prov"] == "anthropic":
            return r["content"][0]["text"], None
        return r["choices"][0]["message"]["content"], None
    except Exception as ex:
        return None, f"Não consegui falar com a IA {cfg['prov']}: {str(ex)[:200]}"

# ---------- 1. Coletor de concursos ----------
LAST = {"fontes": [], "novos": 0, "erro": ""}
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"}

def coletar_sync():
    try:
        novos = 0
        fontes = []
        LAST.update(fontes=[], novos=0, erro="rodando", andamento=0)
        for k, (uf0, url) in enumerate(FEEDS):
            info = {"uf": uf0, "recebidas": 0, "aceitas": 0, "erro": ""}
            try:
                r = httpx.get(url, headers=UA, timeout=15, follow_redirects=True)
                info["http"] = r.status_code
                itens = feedparser.parse(r.text).entries[:30]
                info["recebidas"] = len(itens)
            except Exception as ex:
                info["erro"] = str(ex)[:200]
                fontes.append(info)
                LAST.update(fontes=list(fontes), andamento=k + 1)
                continue
            for e in itens:
                t = f"{e.get('title', '')} {e.get('summary', '')}".lower()
                if "concurso" not in t and "edital" not in t:
                    continue
                if re.search(r"resultado|gabarito|homologa|convocad|nomead|classificad", t):
                    continue
                status = "previsto" if re.search(r"previst|autoriz|comiss[aã]o|ser[aá] realizado|deve sair", t) else "aberto"
                uf = uf0 if uf0 != "BR" else next((u for u in NOMES if re.search(rf"\b{u}\b", e.get("title", ""))), "BR")
                try:
                    db.execute("insert into concursos(titulo,uf,status,link,data) values(?,?,?,?,?)",
                               (e.title, uf, status, e.link, e.get("published", "")))
                    novos += 1
                    info["aceitas"] += 1
                except sqlite3.IntegrityError:
                    pass
            fontes.append(info)
            LAST.update(fontes=list(fontes), novos=novos, andamento=k + 1)
        db.commit()
        LAST.update(fontes=fontes, novos=novos, erro="", andamento=len(FEEDS))
        return {"novos": novos}
    except Exception:
        import traceback
        LAST.update(erro=traceback.format_exc()[-1500:])
        print("ERRO NA BUSCA:", traceback.format_exc(), flush=True)

@app.get("/diagnostico")
def diagnostico():
    total = rows("select count(*) as n from concursos")[0]["n"]
    LAST["andamento"] = LAST.get("andamento", 0)
    return {"concursos_no_banco": total, "ultima_busca": LAST}

SEED = [
    ("Exemplo", 2024, "Português", "facil", "Assinale a frase com a concordância verbal correta.",
     [["A", "Haviam muitos candidatos."], ["B", "Fazem dois anos que estudo."], ["C", "Houve muitos candidatos."], ["D", "Existe muitos candidatos."]], "C"),
    ("Exemplo", 2024, "Raciocínio Lógico", "medio", "A negação de “todo aprovado estudou” é:",
     [["A", "Nenhum aprovado estudou."], ["B", "Algum aprovado não estudou."], ["C", "Todo aprovado não estudou."], ["D", "Algum reprovado estudou."]], "B"),
    ("Exemplo", 2024, "Direito Administrativo", "medio", "O princípio que exige que o administrador faça apenas o que a lei autoriza é o da:",
     [["A", "Legalidade"], ["B", "Eficiência"], ["C", "Moralidade"], ["D", "Publicidade"]], "A"),
    ("Exemplo", 2024, "Informática", "facil", "O atalho padrão para copiar um item selecionado no Windows é:",
     [["A", "Ctrl+V"], ["B", "Ctrl+X"], ["C", "Ctrl+C"], ["D", "Ctrl+Z"]], "C"),
    ("Exemplo", 2024, "Matemática", "dificil", "Se 3 operários fazem uma obra em 12 dias, 4 operários, no mesmo ritmo, farão em:",
     [["A", "8 dias"], ["B", "9 dias"], ["C", "10 dias"], ["D", "16 dias"]], "B"),
]
if not rows("select 1 from questoes limit 1"):
    for b, a, m, n, e, al, g in SEED:
        db.execute("insert into questoes(banca,ano,materia,nivel,enunciado,alts,gabarito) values(?,?,?,?,?,?,?)",
                   (b, a, m, n, e, json.dumps(al, ensure_ascii=False), g))
    db.commit()

@app.api_route("/coletar", methods=["GET", "POST"])
def coletar():
    threading.Thread(target=coletar_sync, daemon=True).start()
    return {"status": "busca iniciada; em 2 minutos recarregue o app"}

@app.on_event("startup")
def iniciar():
    threading.Thread(target=coletar_sync, daemon=True).start()

@app.get("/concursos")
def concursos(uf: str = "", status: str = ""):
    return rows("select * from concursos where (?='' or uf=?) and (?='' or status=?) order by id desc limit 200",
                (uf, uf, status, status))

# ---------- 2. Importar PDF de prova autorizada ----------
@app.post("/provas/importar")
async def importar(arq: UploadFile, banca: str = Form(), ano: int = Form(), materia: str = Form(),
                   nivel: str = Form("medio"), gabarito: str = Form("")):
    with pdfplumber.open(arq.file) as pdf:
        texto = "\n".join(p.extract_text() or "" for p in pdf.pages)
    blocos = re.split(r"\n\s*quest[aã]o\s+\d+\s*\n", texto, flags=re.I)[1:]
    n = 0
    for i, b in enumerate(blocos):
        alts = re.findall(r"^\(?([A-E])[\)\.]\s*(.+)$", b, flags=re.M)
        if len(alts) < 4:
            continue
        enun = re.split(r"^\(?A[\)\.]", b, flags=re.M)[0].strip()
        g = gabarito[i] if i < len(gabarito) else ""
        db.execute("insert into questoes(banca,ano,materia,nivel,enunciado,alts,gabarito) values(?,?,?,?,?,?,?)",
                   (banca, ano, materia, nivel, enun, json.dumps(alts, ensure_ascii=False), g.upper()))
        n += 1
    db.commit()
    return {"importadas": n}

# ---------- 2A. Filtros profissionais ----------
@app.get("/questoes/filtros")
def questoes_filtros():
    bancas = [r["v"] for r in rows("select distinct banca as v from questoes where trim(coalesce(banca,''))!='' order by banca")]
    materias = [r["v"] for r in rows("select distinct materia as v from questoes where trim(coalesce(materia,''))!='' order by materia")]
    anos = [r["v"] for r in rows("select distinct ano as v from questoes where ano is not null and ano>0 order by ano desc")]
    niveis = [r["v"] for r in rows("select distinct nivel as v from questoes where trim(coalesce(nivel,''))!='' order by nivel")]
    return {"bancas": bancas, "materias": materias, "anos": anos,
            "niveis": niveis or ["facil", "medio", "dificil"]}

def _consultar_questoes(banca="", materia="", ano=0, nivel="", busca="", ordem="recentes", limit=20, offset=0):
    limit = max(1, min(int(limit), 100))
    offset = max(0, int(offset))
    busca = busca.strip()
    where = [
        "(?='' or lower(coalesce(banca,''))=lower(?))",
        "(?='' or lower(coalesce(materia,''))=lower(?))",
        "(?=0 or ano=?)",
        "(?='' or lower(coalesce(nivel,''))=lower(?))",
        "(?='' or lower(coalesce(enunciado,'') || ' ' || coalesce(materia,'') || ' ' || coalesce(banca,'')) like lower(?))",
    ]
    args = [banca, banca, materia, materia, ano, ano, nivel, nivel, busca, f"%{busca}%"]
    where_sql = " and ".join(where)
    order_sql = {"recentes": "ano desc, id desc", "antigas": "ano asc, id asc", "aleatorias": "random()"}.get(ordem, "ano desc, id desc")
    total = rows(f"select count(*) as n from questoes where {where_sql}", args)[0]["n"]
    resultado = rows(f"select * from questoes where {where_sql} order by {order_sql} limit ? offset ?",
                     args + [limit, offset])
    for q in resultado:
        try:
            q["alts"] = json.loads(q["alts"]) if isinstance(q["alts"], str) else (q["alts"] or [])
        except (json.JSONDecodeError, TypeError):
            q["alts"] = []
    return {"items": resultado, "total": total}

@app.get("/questoes/pesquisa")
def questoes_pesquisa(banca: str = "", materia: str = "", ano: int = 0, nivel: str = "",
                      busca: str = "", ordem: str = "recentes", limit: int = 20, offset: int = 0):
    return _consultar_questoes(banca, materia, ano, nivel, busca, ordem, limit, offset)

# Compatibilidade com versões antigas do app: /questoes continua retornando uma lista.
@app.get("/questoes")
def questoes(banca: str = "", materia: str = "", ano: int = 0, nivel: str = "", limit: int = 20,
             busca: str = "", ordem: str = "aleatorias", offset: int = 0):
    return _consultar_questoes(banca, materia, ano, nivel, busca, ordem, limit, offset)["items"]

# ---------- 3. Comentários (IA + alunos + professores) ----------
@app.get("/questoes/{qid}/comentarios")
def comentarios(qid: int, cfg: dict = Depends(cfgia)):
    banco = rows("select * from comentarios where questao_id=? and tipo!='ia' or (questao_id=? and tipo='ia' and autor='IA')", (qid, qid))
    if not cfg["key"]:
        return [{"id": 0, "autor": "Sistema", "tipo": "sistema",
                 "texto": "Configure sua IA no ícone do robô no topo para ver o comentário da IA."}] + banco
    if not rows("select 1 from comentarios where questao_id=? and tipo='ia'", (qid,)):
        q = rows("select * from questoes where id=?", (qid,))
        if not q:
            raise HTTPException(status_code=404, detail="Questão não encontrada")
        texto, erro = ia(f"Comente esta questão de concurso, explique por que o gabarito {q[0]['gabarito']} está certo e as demais erradas, cite a base legal quando houver:\n{q[0]['enunciado']}\n{q[0]['alts']}", cfg, 800)
        if erro:
            return [{"id": 0, "autor": "Sistema", "tipo": "sistema", "texto": erro}] + banco
        db.execute("insert into comentarios(questao_id,autor,tipo,texto) values(?,?,?,?)", (qid, "IA", "ia", texto))
        db.commit()
        banco = rows("select * from comentarios where questao_id=? and tipo!='ia' or (questao_id=? and tipo='ia' and autor='IA')", (qid, qid))
    return banco

class Com(BaseModel):
    autor: str
    tipo: str = "aluno"
    texto: str

@app.post("/questoes/{qid}/comentarios")
def comentar(qid: int, c: Com):
    db.execute("insert into comentarios(questao_id,autor,tipo,texto) values(?,?,?,?)",
               (qid, c.autor, "aluno", c.texto))
    db.commit()
    return {"ok": True}

# ---------- 4. Simulados ----------
@app.get("/simulado")
def simulado(banca: str = "", materia: str = "", nivel: str = "medio", n: int = 20):
    return questoes(banca=banca, materia=materia, nivel=nivel, limit=n, ordem="aleatorias")

# ---------- 5. Gerador de apostila ----------
class Edital(BaseModel):
    conteudo: str

@app.post("/apostila")
def apostila(e: Edital, cfg: dict = Depends(cfgia)):
    if not cfg["key"]:
        return {"topicos": [], "apostila": "Configure sua IA (ícone do robô no topo) para gerar apostilas."}
    resp, erro = ia(f"Divida este conteúdo programático em tópicos de estudo. Responda só um array JSON de strings:\n{e.conteudo}", cfg, 1500)
    if erro:
        return {"topicos": [], "apostila": erro}
    m = re.search(r"\[.*\]", resp, re.S)
    try:
        topicos = json.loads(m.group(0)) if m else []
    except Exception:
        topicos = []
    if not topicos:
        return {"topicos": [], "apostila": "A IA não devolveu os tópicos em formato válido. Resposta: " + resp[:300]}
    caps = []
    for t in topicos[:6]:
        cap, erro = ia(f"Escreva um capítulo completo de apostila para concurso sobre '{t}': teoria detalhada, quadro comparativo, exemplos, pegadinhas de banca, base legal citada e 5 exercícios com gabarito. Não invente leis.", cfg, 3500)
        caps.append(f"# {t}\n" + (cap if not erro else erro))
    return {"topicos": topicos, "apostila": "\n\n".join(caps)}
