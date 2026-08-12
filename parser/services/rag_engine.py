import os
import json
import re
import numpy as np
import spacy
from typing import Dict, List, Any, Tuple

# Load spaCy model for PII entity recognition and tokenization
try:
    nlp = spacy.load("en_core_web_sm")
except Exception:
    import spacy.cli
    spacy.cli.download("en_core_web_sm")
    nlp = spacy.load("en_core_web_sm")

# Path to the official Ethiopian Labour Proclamation No. 1156/2019 JSON file
PROCLAMATION_JSON_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "jsons", "labour_proclamation_1156_2019.json")
)

# -----------------------------------------------------------------------------
# 1. Privacy Anonymization & De-Identification Engine (0 Disk / 0 External AI)
# -----------------------------------------------------------------------------
EMAIL_REGEX = re.compile(r"[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+")
PHONE_REGEX = re.compile(r"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}")
SSN_REGEX = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
ACCOUNT_REGEX = re.compile(r"\b(?:account|acct|iban|routing)\s*#?\s*:?\s*([A-Za-z0-9-]+)\b", re.IGNORECASE)
STREET_ADDRESS_REGEX = re.compile(r"\b\d{1,5}\s+[A-Z][a-z]+\s+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way)\b", re.IGNORECASE)

def anonymize_text(raw_text: str) -> Tuple[str, Dict[str, str]]:
    """
    Scans raw text using regex and spaCy NER to redact sensitive user information (PII/PHI)
    BEFORE any vector embedding or retrieval processing.
    """
    mapping: Dict[str, str] = {}
    counters: Dict[str, int] = {
        "PERSON": 1,
        "EMAIL": 1,
        "PHONE": 1,
        "SSN": 1,
        "ADDRESS": 1,
        "ACCOUNT": 1
    }

    sanitized = raw_text

    # 1. Regex Redactions
    for match in SSN_REGEX.finditer(raw_text):
        val = match.group(0)
        if val not in mapping:
            token = f"<SSN_{counters['SSN']}>"
            counters["SSN"] += 1
            mapping[val] = token
            sanitized = sanitized.replace(val, token)

    for match in EMAIL_REGEX.finditer(raw_text):
        val = match.group(0)
        if val not in mapping:
            token = f"<EMAIL_{counters['EMAIL']}>"
            counters["EMAIL"] += 1
            mapping[val] = token
            sanitized = sanitized.replace(val, token)

    for match in PHONE_REGEX.finditer(raw_text):
        val = match.group(0)
        if val not in mapping:
            token = f"<PHONE_{counters['PHONE']}>"
            counters["PHONE"] += 1
            mapping[val] = token
            sanitized = sanitized.replace(val, token)

    for match in STREET_ADDRESS_REGEX.finditer(raw_text):
        val = match.group(0)
        if val not in mapping:
            token = f"<ADDRESS_{counters['ADDRESS']}>"
            counters["ADDRESS"] += 1
            mapping[val] = token
            sanitized = sanitized.replace(val, token)

    for match in ACCOUNT_REGEX.finditer(raw_text):
        val = match.group(1)
        if val and val not in mapping:
            token = f"<ACCOUNT_{counters['ACCOUNT']}>"
            counters["ACCOUNT"] += 1
            mapping[val] = token
            sanitized = sanitized.replace(val, token)

    # 2. spaCy Named Entity Redactions (Person Names)
    doc = nlp(sanitized)
    for ent in doc.ents:
        if ent.label_ == "PERSON":
            val = ent.text.strip()
            if val and len(val) > 2 and val not in mapping and not val.startswith("<"):
                token = f"<PERSON_{counters['PERSON']}>"
                counters["PERSON"] += 1
                mapping[val] = token
                sanitized = sanitized.replace(val, token)

    return sanitized, mapping


# -----------------------------------------------------------------------------
# 2. In-Memory Vector Index & Local Dense Retriever
# -----------------------------------------------------------------------------
class InMemoryVectorIndex:
    """Zero-disk persistence vector index using local spaCy token vector averages."""
    def __init__(self, items: List[Dict[str, Any]] | None = None, raw_text: str | None = None):
        self.chunks: List[Dict[str, Any]] = []
        self.vectors: List[np.ndarray] = []

        if items:
            for idx, item in enumerate(items):
                text_content = item.get("text") or item.get("full_text") or ""
                if not text_content.strip():
                    continue
                vec = self._text_to_vector(text_content)
                self.chunks.append({**item, "chunk_id": idx, "text": text_content})
                self.vectors.append(vec)
        elif raw_text:
            self._build_from_text(raw_text)

        if self.vectors:
            self.matrix = np.vstack(self.vectors)
        else:
            self.matrix = np.zeros((1, 128), dtype=np.float32)

    def _text_to_vector(self, text: str) -> np.ndarray:
        doc = nlp(text)
        if doc.has_vector and doc.vector_norm != 0:
            vec = doc.vector
        else:
            vec = np.zeros(128, dtype=np.float32)
            for token in doc:
                if not token.is_stop and not token.is_punct:
                    idx = abs(hash(token.lemma_.lower())) % 128
                    vec[idx] += 1.0
            norm = np.linalg.norm(vec)
            if norm > 0:
                vec = vec / norm
        return vec

    def _build_from_text(self, text: str):
        paragraphs = text.split("\n\n")
        pos = 0
        for idx, para in enumerate(paragraphs):
            para_str = para.strip()
            start_offset = text.find(para, pos)
            if start_offset == -1:
                start_offset = pos
            end_offset = start_offset + len(para)
            pos = end_offset

            if len(para_str) < 15:
                continue

            vec = self._text_to_vector(para_str)
            self.chunks.append({
                "chunk_id": idx,
                "text": para_str,
                "start_char": start_offset,
                "end_char": end_offset,
            })
            self.vectors.append(vec)

    def query(self, query_str: str, top_k: int = 3) -> List[Dict[str, Any]]:
        if not self.chunks or len(self.vectors) == 0:
            return []

        q_vec = self._text_to_vector(query_str)
        norm_q = np.linalg.norm(q_vec)
        norm_m = np.linalg.norm(self.matrix, axis=1)
        norm_m[norm_m == 0] = 1e-9

        scores = np.dot(self.matrix, q_vec) / (norm_m * (norm_q if norm_q != 0 else 1e-9))
        top_indices = np.argsort(scores)[::-1][:top_k]

        results = []
        for idx in top_indices:
            results.append({
                **self.chunks[idx],
                "similarity": float(scores[idx])
            })
        return results


# -----------------------------------------------------------------------------
# 3. Ethiopian Labour Proclamation No. 1156/2019 Legal Corpus Manager
# -----------------------------------------------------------------------------
class EthiopianLabourProclamationCorpus:
    """
    Loads and structures all 193 articles from parser/jsons/labour_proclamation_1156_2019.json
    into an indexed in-memory legal knowledge base.
    """
    def __init__(self, json_path: str = PROCLAMATION_JSON_PATH):
        self.json_path = json_path
        self.metadata: Dict[str, Any] = {}
        self.articles: List[Dict[str, Any]] = []
        self._load_and_parse()
        self.index = InMemoryVectorIndex(items=self.articles)

    def _load_and_parse(self):
        if not os.path.exists(self.json_path):
            return

        with open(self.json_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.metadata = {
            "proclamation_title": data.get("proclamation_title", "Labour Proclamation No. 1156/2019"),
            "country": data.get("country", "Federal Democratic Republic of Ethiopia"),
            "publication": data.get("publication", "Federal Negarit Gazette No. 89, 5th September 2019")
        }

        def traverse(node: Any, context_path: str = ""):
            if isinstance(node, dict):
                ctx = context_path
                if "title" in node and node["title"]:
                    ctx = f"{ctx} > {node['title']}" if ctx else node["title"]

                if "article_number" in node:
                    art_num = node["article_number"]
                    art_title = node.get("title", "")
                    art_text = node.get("text", "")
                    sub_arts = node.get("sub_articles", [])

                    sub_texts = []
                    for sa in sub_arts:
                        sa_num = sa.get("sub_article_number", "")
                        sa_text = sa.get("text", "")
                        clauses = sa.get("clauses", [])
                        c_texts = [f"({c.get('clause','')}) {c.get('text','')}" for c in clauses]
                        full_sa = f"({sa_num}) {sa_text} " + " ".join(c_texts)
                        sub_texts.append(full_sa)

                    full_art_text = f"Article {art_num} - {art_title}: {art_text} " + " ".join(sub_texts)
                    self.articles.append({
                        "article_number": art_num,
                        "title": art_title,
                        "context": ctx,
                        "text": full_art_text.strip(),
                        "full_text": full_art_text.strip()
                    })

                for k, v in node.items():
                    if k != "sub_articles":
                        traverse(v, ctx)
            elif isinstance(node, list):
                for item in node:
                    traverse(item, context_path)

        traverse(data)

    def search_proclamation(self, query: str, top_k: int = 2) -> List[Dict[str, Any]]:
        return self.index.query(query, top_k=top_k)


# Initialize global Ethiopian Labour Proclamation Corpus singleton
proclamation_corpus = EthiopianLabourProclamationCorpus()


# -----------------------------------------------------------------------------
# 4. Ethiopian Labour Proclamation Fact Extractor for Prolog Reasoning
# -----------------------------------------------------------------------------
ETHIOPIAN_LABOUR_QUERIES = {
    "probation": "probation period probationary trial period testing suitability 60 working days Article 11",
    "working_hours": "working hours normal hours 8 hours a day 48 hours a week Article 61",
    "overtime": "overtime work rates 1.25 1.5 1.75 2.0 2.5 rest day public holiday Article 67 68",
    "termination_notice": "notice of termination notice period 30 days 1 month 2 months 3 months Article 35 44",
    "annual_leave": "annual leave 16 working days vacation paid annual leave Article 77",
    "maternity_leave": "maternity leave 120 consecutive days 30 days prenatal 90 days postnatal Article 88",
    "sick_leave": "sick leave 6 months medical certificate 100 percent 50 percent pay Article 85",
    "minimum_age": "minimum age employment 15 years young worker Article 89",
    "severance_pay": "severance pay 30 days monthly wage termination compensation Article 39",
    "prohibited_acts": "prohibited acts discrimination sexual harassment sexual assault forced labor Article 14",
    "written_contract": "written contract element 15 days letter Article 4 6 7"
}

def extract_rag_compliance_facts(raw_text: str) -> Dict[str, Any]:
    """
    Ethiopian Labour Proclamation No. 1156/2019 RAG Pipeline:
    1. Anonymize user sensitive data (PII/PHI redacted to <PERSON_X>, <EMAIL_X>, etc.).
    2. Build in-memory vector index over uploaded document.
    3. Query document using Ethiopian Labour Law queries.
    4. Retrieve corresponding reference Articles from parser/jsons/labour_proclamation_1156_2019.json.
    5. Extract structured compliance facts for SWI-Prolog reasoning against Proclamation 1156/2019.
    """
    # 1. De-identify sensitive text
    sanitized_text, pii_map = anonymize_text(raw_text)

    # 2. Build local vector index over uploaded document in RAM
    doc_index = InMemoryVectorIndex(raw_text=sanitized_text)

    # 3. Retrieve domain contexts from contract + Ethiopian Labour Proclamation Corpus
    retrieved_doc_contexts: Dict[str, List[Dict[str, Any]]] = {}
    retrieved_proclamation_articles: Dict[str, List[Dict[str, Any]]] = {}

    for key, q_str in ETHIOPIAN_LABOUR_QUERIES.items():
        retrieved_doc_contexts[key] = doc_index.query(q_str, top_k=2)
        retrieved_proclamation_articles[key] = proclamation_corpus.search_proclamation(q_str, top_k=1)

    # 4. Synthesize Prolog Facts matching Ethiopian Labour Proclamation standards
    prolog_facts: Dict[str, Any] = {
        "domain": "ethiopian_labour_proclamation",
        "governing_law": "Ethiopian Labour Proclamation No. 1156/2019",
        "jurisdiction": "Ethiopia"
    }

    # Extract Probation Period (Legal max: 60 working days per Article 11(3))
    prob_chunks = retrieved_doc_contexts.get("probation", [])
    for c in prob_chunks:
        m_days = re.search(r"(?i)\b(\d+)\s*(?:working\s+)?days?\b", c["text"])
        m_months = re.search(r"(?i)\b(\d+)\s*months?\b", c["text"])
        if m_days:
            prolog_facts["probation_days"] = int(m_days.group(1))
            break
        elif m_months:
            prolog_facts["probation_days"] = int(m_months.group(1)) * 30
            break

    # Extract Working Hours (Legal max: 8 hrs/day, 48 hrs/week per Article 61)
    wh_chunks = retrieved_doc_contexts.get("working_hours", [])
    for c in wh_chunks:
        m_day = re.search(r"(?i)\b(\d+)\s*(?:hours?|hrs?)\s*(?:per|a|\/)\s*day\b", c["text"])
        m_week = re.search(r"(?i)\b(\d+)\s*(?:hours?|hrs?)\s*(?:per|a|\/)\s*week\b", c["text"])
        if m_day:
            prolog_facts["working_hours_per_day"] = int(m_day.group(1))
        if m_week:
            prolog_facts["weekly_working_hours"] = int(m_week.group(1))

    # Extract Termination Notice Period (Articles 35 & 44)
    notice_chunks = retrieved_doc_contexts.get("termination_notice", [])
    for c in notice_chunks:
        m_days = re.search(r"(?i)\b(\d+)\s*days?\s+(?:written\s+)?notice\b", c["text"]) or re.search(r"(?i)notice[^\.\n]*?\b(\d+)\s*days?\b", c["text"])
        m_months = re.search(r"(?i)\b(\d+)\s*months?\s+(?:written\s+)?notice\b", c["text"])
        if m_days:
            prolog_facts["notice_period_days"] = int(m_days.group(1))
            break
        elif m_months:
            prolog_facts["notice_period_days"] = int(m_months.group(1)) * 30
            break

    # Extract Annual Leave (Legal min: 16 working days per Article 77(1))
    al_chunks = retrieved_doc_contexts.get("annual_leave", [])
    for c in al_chunks:
        m_days = re.search(r"(?i)annual\s+leave[^\.\n]*?\b(\d+)\s*(?:working\s+)?days?\b", c["text"]) or re.search(r"(?i)\b(\d+)\s*(?:working\s+)?days?\s+(?:of\s+)?annual\s+leave\b", c["text"])
        if m_days:
            prolog_facts["annual_leave_days"] = int(m_days.group(1))
            break

    # Extract Maternity Leave (Legal min: 120 consecutive days per Article 88(2-3))
    ml_chunks = retrieved_doc_contexts.get("maternity_leave", [])
    for c in ml_chunks:
        m_days = re.search(r"(?i)maternity\s+leave[^\.\n]*?\b(\d+)\s*(?:consecutive\s+)?days?\b", c["text"]) or re.search(r"(?i)\b(\d+)\s*(?:consecutive\s+)?days?\s+(?:of\s+)?maternity\s+leave\b", c["text"])
        m_months = re.search(r"(?i)maternity\s+leave[^\.\n]*?\b(\d+)\s*months?\b", c["text"])
        if m_days:
            prolog_facts["maternity_leave_days"] = int(m_days.group(1))
            break
        elif m_months:
            prolog_facts["maternity_leave_days"] = int(m_months.group(1)) * 30
            break

    # Extract Sick Leave (Article 85)
    sl_chunks = retrieved_doc_contexts.get("sick_leave", [])
    for c in sl_chunks:
        m_months = re.search(r"(?i)sick\s+leave[^\.\n]*?\b(\d+)\s*months?\b", c["text"]) or re.search(r"(?i)\b(\d+)\s*months?\s+(?:of\s+)?sick\s+leave\b", c["text"])
        if m_months:
            prolog_facts["sick_leave_months"] = int(m_months.group(1))
            break

    # Extract Minimum Age (Legal min: 15 years per Article 89(1))
    age_chunks = retrieved_doc_contexts.get("minimum_age", [])
    for c in age_chunks:
        m_age = re.search(r"(?i)\b(\d{2})\s*(?:years?\s+old|years?\s+of\s+age)\b", c["text"]) or re.search(r"(?i)age[^\.\n]*?\b(\d{2})\b", c["text"])
        if m_age:
            prolog_facts["minimum_worker_age"] = int(m_age.group(1))
            break


    # Extract Anti-Discrimination & Sexual Harassment Policies (Article 14)
    pa_chunks = retrieved_doc_contexts.get("prohibited_acts", [])
    for c in pa_chunks:
        txt_lower = c["text"].lower()
        if "discrimina" in txt_lower or "equal opportunity" in txt_lower:
            prolog_facts["has_anti_discrimination"] = True
        if "harassment" in txt_lower or "sexual assault" in txt_lower:
            prolog_facts["has_sexual_harassment_policy"] = True

    # Assemble retrieved document chunks + matched Ethiopian Labour Proclamation Articles
    all_chunks = []

    # 1. Document Chunks
    for k, chunk_list in retrieved_doc_contexts.items():
        for chk in chunk_list:
            if chk.get("similarity", 0) > 0.10:
                all_chunks.append({
                    "source": "uploaded_document",
                    "category": k,
                    "snippet": chk["text"][:300],
                    "start_char": chk.get("start_char", 0),
                    "end_char": chk.get("end_char", 0),
                    "similarity": round(chk.get("similarity", 0), 4)
                })

    # 2. Reference Articles from Proclamation No. 1156/2019 JSON
    for k, art_list in retrieved_proclamation_articles.items():
        for art in art_list:
            all_chunks.append({
                "source": "ethiopian_labour_proclamation_1156_2019",
                "category": k,
                "article_number": art.get("article_number"),
                "article_title": art.get("title"),
                "context": art.get("context"),
                "snippet": art.get("text", "")[:350],
                "similarity": round(art.get("similarity", 0), 4)
            })

    return {
        "pii_redacted_count": len(pii_map),
        "sanitized_preview": sanitized_text[:200] + "...",
        "prolog_facts": prolog_facts,
        "retrieved_chunks": all_chunks,
        "proclamation_metadata": proclamation_corpus.metadata
    }

