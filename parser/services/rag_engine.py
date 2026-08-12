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
        """Build vector index from text using paragraph splitting with sentence-level fallback.
        
        Contracts with single-spaced text produce very few large paragraphs when splitting on \\n\\n.
        This method falls back to spaCy sentence tokenization grouped into sliding windows of 3
        sentences, giving the RAG retriever fine-grained chunks to differentiate between clauses.
        """
        paragraphs = text.split("\n\n")
        valid_paragraphs = [p.strip() for p in paragraphs if len(p.strip()) >= 15]

        if len(valid_paragraphs) > 3:
            # Paragraph-level chunking (document has clear paragraph separation)
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
        else:
            # Sentence-level chunking fallback (single-spaced or dense text)
            doc = nlp(text)
            sentences = list(doc.sents)
            window_size = 3
            for idx in range(0, len(sentences), max(1, window_size - 1)):
                group = sentences[idx:idx + window_size]
                chunk_text = " ".join(s.text.strip() for s in group)
                start_offset = group[0].start_char
                end_offset = group[-1].end_char

                if len(chunk_text.strip()) < 15:
                    continue

                vec = self._text_to_vector(chunk_text)
                self.chunks.append({
                    "chunk_id": idx,
                    "text": chunk_text.strip(),
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
    "probation": "probation period probationary trial period testing suitability 60 working days 12 months Article 11",
    "working_hours": "working hours normal hours 8 hours a day 48 hours a week 78 hours Article 61",
    "overtime": "overtime work rates unpaid overtime mandatory overtime 1.25 1.5 1.75 2.0 2.5 Article 67 68",
    "termination_notice": "notice of termination notice period 30 days 1 month 2 months 3 months Article 35 44",
    "annual_leave": "annual leave 16 working days vacation paid annual leave no leave first 3 years Article 77",
    "maternity_leave": "maternity leave 120 consecutive days 30 days prenatal 90 days postnatal unpaid maternity forced resignation Article 88",
    "sick_leave": "sick leave 6 months medical certificate 100 percent 50 percent pay Article 85",
    "minimum_age": "minimum age employment 15 years young worker 15-17 adult schedule Article 89 90",
    "severance_pay": "severance pay 30 days monthly wage termination compensation forfeit severance Article 39 40",
    "prohibited_acts": "prohibited acts discrimination sexual harassment sexual assault forced labor Article 14",
    "written_contract": "written contract element 15 days letter Article 4 6 7",
    "hiring_discrimination": "applicant restriction sex gender male female religion marital status single married Article 14 87",
    "pregnancy_discrimination": "pregnant pregnancy test maternity exclusion terminate pregnancy childbirth resignation Article 14 88",
    "weekly_rest": "weekly rest day 7 days a week continuous work rest day denied Article 70",
    "ppe_safety": "personal protective equipment ppe purchase safety gear worker buys ppe cost Article 92 93",
    "labour_inspection": "labour inspector government inspector ban contact inspector report violation Article 181",
    "trade_union": "trade union union membership ban union terminate union organization Article 14 26",
    "dispute_waiver": "appeal dismissal labour board court waive dispute resolution rights Article 138"
}

def extract_number_near_keyword(
    text: str, keywords: List[str], unit_pattern: str, max_dist: int = 60
) -> Tuple[int | None, str | None]:
    """
    Extract a number that appears within `max_dist` characters of specified keywords inside a sentence.
    Returns (extracted_number, sentence_snippet).
    """
    doc = nlp(text)
    for sent in doc.sents:
        sent_text = sent.text.strip()
        sent_lower = sent_text.lower()
        if any(kw.lower() in sent_lower for kw in keywords):
            for kw in keywords:
                kw_lower = kw.lower()
                kw_idx = sent_lower.find(kw_lower)
                if kw_idx != -1:
                    win_start = max(0, kw_idx - max_dist)
                    win_end = min(len(sent_text), kw_idx + len(kw) + max_dist)
                    window = sent_text[win_start:win_end]
                    match = re.search(rf"(?i)\b(\d+)\s*{unit_pattern}", window)
                    if match:
                        return int(match.group(1)), sent_text
    return None, None


def extract_rag_compliance_facts(raw_text: str) -> Dict[str, Any]:
    """
    Ethiopian Labour Proclamation No. 1156/2019 RAG Pipeline:
    1. Anonymize user sensitive data (PII/PHI redacted to <PERSON_X>, <EMAIL_X>, etc.).
    2. Build in-memory vector index over uploaded document.
    3. Query document using Ethiopian Labour Law queries.
    4. Retrieve corresponding reference Articles from parser/jsons/labour_proclamation_1156_2019.json.
    5. Extract structured compliance facts for SWI-Prolog reasoning against Proclamation 1156/2019 with provenance.
    """
    # 1. De-identify sensitive text
    sanitized_text, pii_map = anonymize_text(raw_text)

    # 2. Build local vector index over uploaded document in RAM (with sentence-level fallback)
    doc_index = InMemoryVectorIndex(raw_text=sanitized_text)

    # 3. Retrieve domain contexts from contract + Ethiopian Labour Proclamation Corpus
    retrieved_doc_contexts: Dict[str, List[Dict[str, Any]]] = {}
    retrieved_proclamation_articles: Dict[str, List[Dict[str, Any]]] = {}

    for key, q_str in ETHIOPIAN_LABOUR_QUERIES.items():
        retrieved_doc_contexts[key] = doc_index.query(q_str, top_k=2)
        retrieved_proclamation_articles[key] = proclamation_corpus.search_proclamation(q_str, top_k=1)

    # 4. Synthesize Prolog Facts matching Ethiopian Labour Proclamation standards + Fact Provenance
    prolog_facts: Dict[str, Any] = {
        "domain": "ethiopian_labour_proclamation",
        "governing_law": "Ethiopian Labour Proclamation No. 1156/2019",
        "jurisdiction": "Ethiopia"
    }
    fact_provenance: Dict[str, Any] = {}

    # Extract Probation Period (Legal max: 60 working days per Article 11(3))
    prob_chunks = retrieved_doc_contexts.get("probation", [])
    for c in prob_chunks:
        val_days, snippet = extract_number_near_keyword(c["text"], ["probation", "trial period", "testing"], r"(?:working\s+)?days?")
        val_months, snippet_m = extract_number_near_keyword(c["text"], ["probation", "trial period", "testing"], r"months?")
        if val_days is not None:
            prolog_facts["probation_days"] = val_days
            fact_provenance["probation_days"] = {
                "value": val_days,
                "source_text": snippet[:200] if snippet else c["text"][:200],
                "article_reference": "Article 11(3)"
            }
            break
        elif val_months is not None:
            prolog_facts["probation_days"] = val_months * 30
            fact_provenance["probation_days"] = {
                "value": val_months * 30,
                "source_text": snippet_m[:200] if snippet_m else c["text"][:200],
                "article_reference": "Article 11(3)"
            }
            break

    # Extract Working Hours (Legal max: 8 hrs/day, 48 hrs/week per Article 61)
    wh_chunks = retrieved_doc_contexts.get("working_hours", [])
    for c in wh_chunks:
        val_day, snip_d = extract_number_near_keyword(c["text"], ["hour", "hrs", "working", "daily"], r"(?:hours?|hrs?)\s*(?:per|a|\/)?\s*day")
        val_week, snip_w = extract_number_near_keyword(c["text"], ["hour", "hrs", "working", "weekly"], r"(?:hours?|hrs?)\s*(?:per|a|\/)?\s*week")
        if val_day is not None:
            prolog_facts["working_hours_per_day"] = val_day
            fact_provenance["working_hours_per_day"] = {
                "value": val_day,
                "source_text": snip_d[:200] if snip_d else c["text"][:200],
                "article_reference": "Article 61(1)"
            }
        if val_week is not None:
            prolog_facts["weekly_working_hours"] = val_week
            fact_provenance["weekly_working_hours"] = {
                "value": val_week,
                "source_text": snip_w[:200] if snip_w else c["text"][:200],
                "article_reference": "Article 61(1)"
            }

    # Extract Overtime Hours (Legal max: 2 hrs/day per Article 67)
    ot_chunks = retrieved_doc_contexts.get("overtime", [])
    for c in ot_chunks:
        val_ot, snip_ot = extract_number_near_keyword(c["text"], ["overtime", "extra hours"], r"(?:hours?|hrs?)\s*(?:per|a|\/)?\s*day")
        if val_ot is not None:
            prolog_facts["overtime_hours_per_day"] = val_ot
            fact_provenance["overtime_hours_per_day"] = {
                "value": val_ot,
                "source_text": snip_ot[:200] if snip_ot else c["text"][:200],
                "article_reference": "Article 67"
            }
            break

    # Extract Termination Notice Period (Articles 35 & 44)
    notice_chunks = retrieved_doc_contexts.get("termination_notice", [])
    for c in notice_chunks:
        val_days, snip_d = extract_number_near_keyword(c["text"], ["notice", "termination", "prior notice"], r"days?")
        val_months, snip_m = extract_number_near_keyword(c["text"], ["notice", "termination", "prior notice"], r"months?")
        if val_days is not None:
            prolog_facts["notice_period_days"] = val_days
            fact_provenance["notice_period_days"] = {
                "value": val_days,
                "source_text": snip_d[:200] if snip_d else c["text"][:200],
                "article_reference": "Articles 35 & 44"
            }
            break
        elif val_months is not None:
            prolog_facts["notice_period_days"] = val_months * 30
            fact_provenance["notice_period_days"] = {
                "value": val_months * 30,
                "source_text": snip_m[:200] if snip_m else c["text"][:200],
                "article_reference": "Articles 35 & 44"
            }
            break

    # Extract Annual Leave (Legal min: 16 working days per Article 77(1))
    al_chunks = retrieved_doc_contexts.get("annual_leave", [])
    for c in al_chunks:
        val_days, snip_al = extract_number_near_keyword(c["text"], ["annual leave", "vacation", "paid leave"], r"(?:working\s+)?days?")
        if val_days is not None:
            prolog_facts["annual_leave_days"] = val_days
            fact_provenance["annual_leave_days"] = {
                "value": val_days,
                "source_text": snip_al[:200] if snip_al else c["text"][:200],
                "article_reference": "Article 77(1)"
            }
            break

    # Extract Maternity Leave (Legal min: 120 consecutive days per Article 88(2-3))
    ml_chunks = retrieved_doc_contexts.get("maternity_leave", [])
    for c in ml_chunks:
        val_days, snip_md = extract_number_near_keyword(c["text"], ["maternity", "pregnancy", "prenatal", "postnatal"], r"(?:consecutive\s+)?days?")
        val_months, snip_mm = extract_number_near_keyword(c["text"], ["maternity", "pregnancy"], r"months?")
        if val_days is not None:
            prolog_facts["maternity_leave_days"] = val_days
            fact_provenance["maternity_leave_days"] = {
                "value": val_days,
                "source_text": snip_md[:200] if snip_md else c["text"][:200],
                "article_reference": "Article 88(2-3)"
            }
            break
        elif val_months is not None:
            prolog_facts["maternity_leave_days"] = val_months * 30
            fact_provenance["maternity_leave_days"] = {
                "value": val_months * 30,
                "source_text": snip_mm[:200] if snip_mm else c["text"][:200],
                "article_reference": "Article 88(2-3)"
            }
            break

    # Extract Sick Leave (Article 85)
    sl_chunks = retrieved_doc_contexts.get("sick_leave", [])
    for c in sl_chunks:
        val_months, snip_sl = extract_number_near_keyword(c["text"], ["sick leave", "medical leave", "incapacity"], r"months?")
        if val_months is not None:
            prolog_facts["sick_leave_months"] = val_months
            fact_provenance["sick_leave_months"] = {
                "value": val_months,
                "source_text": snip_sl[:200] if snip_sl else c["text"][:200],
                "article_reference": "Article 85"
            }
            break

    # Extract Minimum Age (Legal min: 15 years per Article 89(1))
    age_chunks = retrieved_doc_contexts.get("minimum_age", [])
    for c in age_chunks:
        val_age, snip_age = extract_number_near_keyword(c["text"], ["age", "years old", "young worker", "minimum age"], r"(?:years?\s+old|years?\s+of\s+age|years?)")
        if val_age is not None:
            prolog_facts["minimum_worker_age"] = val_age
            fact_provenance["minimum_worker_age"] = {
                "value": val_age,
                "source_text": snip_age[:200] if snip_age else c["text"][:200],
                "article_reference": "Article 89(1)"
            }
            break

    # -------------------------------------------------------------------------
    # Comprehensive Extraction for all 14 Proclamation No. 1156/2019 Violation Categories
    # -------------------------------------------------------------------------
    full_lower = sanitized_text.lower()

    # 1. Hiring Discrimination (Articles 14(1)(b-c) & 87)
    hd_keywords = ["male only", "female only", "women only", "men only", "single only", "unmarried", "religion requirement", "christian only", "muslim only", "restrict applicants by sex", "restrict applicants by gender", "restricted to female", "restricted to male", "marital status requirement"]
    for kw in hd_keywords:
        if kw in full_lower:
            prolog_facts["hiring_discrimination_detected"] = True
            fact_provenance["hiring_discrimination_detected"] = {
                "value": True,
                "source_text": f"Found discriminatory requirement '{kw}' in document text.",
                "article_reference": "Articles 14(1)(b-c) & 87"
            }
            break

    # 2. Pregnancy Discrimination & Mandatory Resignation (Articles 14(1)(b) & 88)
    preg_keywords = ["pregnant", "pregnancy", "childbirth", "maternity test", "resignation upon pregnancy", "terminate if pregnant", "resignation on childbirth", "no pregnant applicants"]
    for kw in preg_keywords:
        if kw in full_lower:
            prolog_facts["pregnancy_discrimination_detected"] = True
            fact_provenance["pregnancy_discrimination_detected"] = {
                "value": True,
                "source_text": f"Found pregnancy restriction/exclusion clause '{kw}' in document text.",
                "article_reference": "Articles 14(1)(b) & 88"
            }
            break

    # 3. Unpaid Mandatory Overtime (Article 68)
    ot_unpaid_kw = ["unpaid overtime", "overtime without pay", "no overtime pay", "overtime included in base salary", "without additional compensation for overtime", "unpaid extra hours"]
    for kw in ot_unpaid_kw:
        if kw in full_lower:
            prolog_facts["unpaid_overtime_detected"] = True
            fact_provenance["unpaid_overtime_detected"] = {
                "value": True,
                "source_text": f"Found unpaid overtime clause '{kw}' in document text.",
                "article_reference": "Article 68"
            }
            break

    # 4. Denial of Mandatory Weekly Rest Day (Article 70)
    wr_kw = ["no weekly rest", "7 days a week", "seven days a week", "continuous work without rest", "no rest day for", "waive weekly rest"]
    for kw in wr_kw:
        if kw in full_lower:
            prolog_facts["weekly_rest_denied"] = True
            fact_provenance["weekly_rest_denied"] = {
                "value": True,
                "source_text": f"Found weekly rest day denial clause '{kw}' in document text.",
                "article_reference": "Article 70"
            }
            break

    # 5. Multi-Year Annual Leave Denial / Delay (Article 77(1) & (4))
    al_deny_kw = ["no annual leave for the first", "no leave for the first", "leave begins after 3 years", "leave after 2 years", "forfeiture of annual leave", "no annual leave during the first"]
    for kw in al_deny_kw:
        if kw in full_lower:
            prolog_facts["annual_leave_denied_initial_years"] = True
            fact_provenance["annual_leave_denied_initial_years"] = {
                "value": True,
                "source_text": f"Found annual leave delay/denial clause '{kw}' in document text.",
                "article_reference": "Article 77(1) & (4)"
            }
            break

    # 6. Denial of Paid Maternity Leave (Article 88(2-3))
    ml_deny_kw = ["unpaid maternity leave", "no paid maternity leave", "maternity leave without pay", "maternity leave is unpaid"]
    for kw in ml_deny_kw:
        if kw in full_lower:
            prolog_facts["maternity_leave_denied"] = True
            fact_provenance["maternity_leave_denied"] = {
                "value": True,
                "source_text": f"Found unpaid maternity leave clause '{kw}' in document text.",
                "article_reference": "Article 88(2-3)"
            }
            break

    # 7. Blanket Forfeiture of Severance Pay (Articles 39 & 40)
    sev_forfeit_kw = ["forfeit severance", "forfeiture of severance", "no severance pay", "waive severance", "relinquish severance", "without severance pay"]
    for kw in sev_forfeit_kw:
        if kw in full_lower:
            prolog_facts["severance_forfeited"] = True
            fact_provenance["severance_forfeited"] = {
                "value": True,
                "source_text": f"Found severance pay forfeiture clause '{kw}' in document text.",
                "article_reference": "Articles 39 & 40"
            }
            break

    # 8. Worker Paid Personal Protective Equipment (PPE) (Articles 92 & 93)
    ppe_kw = ["buy own ppe", "worker must purchase", "employee must purchase", "purchase safety gear", "buy protective equipment", "safety gear at worker expense", "ppe at employee cost"]
    for kw in ppe_kw:
        if kw in full_lower:
            prolog_facts["worker_pays_ppe"] = True
            fact_provenance["worker_pays_ppe"] = {
                "value": True,
                "source_text": f"Found worker PPE cost-shifting clause '{kw}' in document text.",
                "article_reference": "Articles 92 & 93"
            }
            break

    # 9. Unlawful Restriction of Access to Labour Inspectors (Article 181)
    li_kw = ["contacting labour inspector", "contact labour inspector", "contact government inspector", "forbidden to contact inspector", "no communication with ministry of labor", "banning inspector access"]
    for kw in li_kw:
        if kw in full_lower:
            prolog_facts["prohibits_labour_inspection"] = True
            fact_provenance["prohibits_labour_inspection"] = {
                "value": True,
                "source_text": f"Found restriction on contacting labour inspectors '{kw}' in document text.",
                "article_reference": "Article 181"
            }
            break

    # 10. Young Workers Full Adult Work Schedule (Articles 89 & 90)
    yw_kw = ["15 to 17", "15-17", "young worker", "ages 15-17", "under 18"]
    if any(k in full_lower for k in yw_kw) and ("8 hours" in full_lower or "full schedule" in full_lower or "normal shift" in full_lower or "78 hours" in full_lower):
        prolog_facts["young_worker_adult_schedule"] = True
        fact_provenance["young_worker_adult_schedule"] = {
            "value": True,
            "source_text": "Found young worker assigned to full adult work schedule exceeding 7 hrs/day.",
            "article_reference": "Article 90"
        }

    # 11. Trade Union Membership Ban (Articles 14(1)(a) & 26(2)(a))
    tu_kw = ["banning trade union", "ban trade union", "no trade union", "prohibit union", "forbidden to join union", "termination for joining union", "no union membership"]
    for kw in tu_kw:
        if kw in full_lower:
            prolog_facts["trade_union_prohibited"] = True
            fact_provenance["trade_union_prohibited"] = {
                "value": True,
                "source_text": f"Found trade union prohibition clause '{kw}' in document text.",
                "article_reference": "Articles 14(1)(a) & 26(2)(a)"
            }
            break

    # 12. Pre-Waiver of Statutory Dispute Resolution / Court Access Rights (Part Nine / Article 138+)
    dw_kw = ["waive right to appeal", "cannot appeal dismissal", "waive court access", "no recourse to labour board", "forfeit appeal rights", "waive dispute resolution"]
    for kw in dw_kw:
        if kw in full_lower:
            prolog_facts["dispute_appeal_waived"] = True
            fact_provenance["dispute_appeal_waived"] = {
                "value": True,
                "source_text": f"Found pre-waiver of dispute resolution/court appeal rights '{kw}' in document text.",
                "article_reference": "Article 138 (Part Nine)"
            }
            break

    # Extract Anti-Discrimination & Sexual Harassment Policies (Article 14)
    pa_chunks = retrieved_doc_contexts.get("prohibited_acts", [])
    for c in pa_chunks:
        txt_lower = c["text"].lower()
        if "discrimina" in txt_lower or "equal opportunity" in txt_lower:
            prolog_facts["has_anti_discrimination"] = True
            fact_provenance["has_anti_discrimination"] = {
                "value": True,
                "source_text": c["text"][:200],
                "article_reference": "Article 14(1)(f)"
            }
        if "harassment" in txt_lower or "sexual assault" in txt_lower:
            prolog_facts["has_sexual_harassment_policy"] = True
            fact_provenance["has_sexual_harassment_policy"] = {
                "value": True,
                "source_text": c["text"][:200],
                "article_reference": "Article 14(1)(h)"
            }

    # Extract Severance Pay & Written Contract Provisions
    sev_chunks = retrieved_doc_contexts.get("severance_pay", [])
    for c in sev_chunks:
        txt_lower = c["text"].lower()
        if "severance" in txt_lower or "termination compensation" in txt_lower:
            prolog_facts["has_severance_provision"] = True
            fact_provenance["has_severance_provision"] = {
                "value": True,
                "source_text": c["text"][:200],
                "article_reference": "Article 39"
            }

    wc_chunks = retrieved_doc_contexts.get("written_contract", [])
    for c in wc_chunks:
        txt_lower = c["text"].lower()
        if "written" in txt_lower or "letter of employment" in txt_lower or "statement of employment" in txt_lower:
            prolog_facts["has_written_contract_provision"] = True
            fact_provenance["has_written_contract_provision"] = {
                "value": True,
                "source_text": c["text"][:200],
                "article_reference": "Article 6"
            }

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
        "fact_provenance": fact_provenance,
        "retrieved_chunks": all_chunks,
        "proclamation_metadata": proclamation_corpus.metadata
    }

