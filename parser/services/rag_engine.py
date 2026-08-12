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
    
    Replaces sensitive data with generic tokens (<PERSON_1>, <EMAIL_1>, <SSN_1>, etc.)
    and holds the mapping purely in volatile memory.
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
    """
    Zero-disk persistence vector index using local spaCy token vector averages
    and n-gram term frequency features.
    """
    def __init__(self, sanitized_text: str):
        self.chunks: List[Dict[str, Any]] = []
        self.vectors: List[np.ndarray] = []
        self._build_index(sanitized_text)

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

    def _build_index(self, text: str):
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

        if self.vectors:
            self.matrix = np.vstack(self.vectors)
        else:
            self.matrix = np.zeros((1, 128), dtype=np.float32)

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
# 3. Domain Fact Extractor for Prolog Reasoning
# -----------------------------------------------------------------------------
REGULATORY_QUERIES = {
    "governing_law": "governing law jurisdiction state laws of the state of choice of law",
    "non_compete": "non-compete non compete restriction compete period months territory business",
    "data_retention": "data storage backup retention period indefinite store non-encrypted",
    "encryption": "data encryption status tls ssl aes security transit rest unencrypted",
    "patching": "vulnerability management patch patching schedule interval 30 days 90 days",
    "sox": "sox section 302 officer certification financial disclosures internal controls",
    "liability": "limitation of liability cap maximum aggregate damages liability"
}

def extract_rag_compliance_facts(raw_text: str) -> Dict[str, Any]:
    """
    RAG Pipeline:
    1. Anonymize user sensitive data (PII/PHI redacted to <PERSON_X>, <EMAIL_X>, etc.).
    2. Build in-memory vector index over sanitized chunks.
    3. Query index locally using regulatory prompts.
    4. Extract structured, anonymized compliance facts for SWI-Prolog reasoning.
    """
    # 1. De-identify sensitive text
    sanitized_text, pii_map = anonymize_text(raw_text)

    # 2. Build local vector index in RAM
    index = InMemoryVectorIndex(sanitized_text)

    # 3. Retrieve domain contexts
    retrieved_contexts: Dict[str, List[Dict[str, Any]]] = {}
    for key, q_str in REGULATORY_QUERIES.items():
        retrieved_contexts[key] = index.query(q_str, top_k=2)

    # 4. Synthesize Prolog Facts matching reasoner-engine rules
    facts: Dict[str, Any] = {
        "pii_redacted_count": len(pii_map),
        "sanitized_preview": sanitized_text[:200] + "...",
        "retrieved_chunks": []
    }

    prolog_facts: Dict[str, Any] = {}

    # Extract Governing Jurisdiction
    gov_chunks = retrieved_contexts.get("governing_law", [])
    for c in gov_chunks:
        m = re.search(r"(?i)\b(?:laws?\s+of\s+(?:the\s+State\s+of\s+)?|State\s+of\s+)([A-Z][a-zA-Z]+)", c["text"])
        if m:
            state_str = m.group(1).strip()
            prolog_facts["jurisdiction"] = state_str
            prolog_facts["governing_state"] = state_str.lower()
            break

    # Extract Non-Compete Duration & Enforceability
    nc_chunks = retrieved_contexts.get("non_compete", [])
    for c in nc_chunks:
        txt_lower = c["text"].lower()
        if "non-compete" in txt_lower or "competing business" in txt_lower or "compete" in txt_lower:
            prolog_facts["non_compete_present"] = True
            prolog_facts["has_non_compete"] = True

        m = re.search(r"(?i)\b(\d+)\s*(?:months?|years?)\b", c["text"])
        if m:
            val = int(m.group(1))
            if "year" in m.group(0).lower():
                val *= 12
            prolog_facts["non_compete_months"] = val
            prolog_facts["non_compete_duration_months"] = val
            break

    # Extract Data Retention & Encryption
    dr_chunks = retrieved_contexts.get("data_retention", []) + retrieved_contexts.get("encryption", [])
    for c in dr_chunks:
        txt_lower = c["text"].lower()
        if "indefinite" in txt_lower:
            prolog_facts["retention_period"] = "indefinite"
            prolog_facts["data_storage_indefinite"] = True

        if "non-encrypted" in txt_lower or "unencrypted" in txt_lower:
            prolog_facts["encryption"] = "none"
            prolog_facts["data_encrypted"] = False
        elif "aes-256" in txt_lower or "encrypted" in txt_lower:
            prolog_facts["encryption"] = "AES-256"
            prolog_facts["data_encrypted"] = True

    # Extract Patching Interval
    patch_chunks = retrieved_contexts.get("patching", [])
    for c in patch_chunks:
        m = re.search(r"(?i)\b(\d+)\s*days\b", c["text"])
        if m:
            days = int(m.group(1))
            prolog_facts["patching_interval_days"] = days
            prolog_facts["patch_frequency_days"] = days
            break

    # Extract SOX Officer Certification
    sox_chunks = retrieved_contexts.get("sox", [])
    for c in sox_chunks:
        if "sox" in c["text"].lower() or "officer certification" in c["text"].lower():
            prolog_facts["sox_302_referenced"] = True

    # Assemble all retrieved chunks for transparency
    all_chunks = []
    for k, chunk_list in retrieved_contexts.items():
        for chk in chunk_list:
            if chk["similarity"] > 0.15:
                all_chunks.append({
                    "category": k,
                    "snippet": chk["text"][:250],
                    "start_char": chk["start_char"],
                    "end_char": chk["end_char"],
                    "similarity": round(chk["similarity"], 4)
                })

    facts["prolog_facts"] = prolog_facts
    facts["retrieved_chunks"] = all_chunks

    return facts
