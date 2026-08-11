import re
from typing import Any, Dict, List
import spacy
from pydantic import BaseModel, Field

# Load spaCy NLP pipeline
try:
    nlp = spacy.load("en_core_web_sm")
except Exception:
    import spacy.cli
    spacy.cli.download("en_core_web_sm")
    nlp = spacy.load("en_core_web_sm")

class EntitySpan(BaseModel):
    text: str = Field(..., description="The matched entity substring")
    label: str = Field(..., description="Category: DATE, MONEY, JURISDICTION, GPE, CLAUSE, etc.")
    start_char: int = Field(..., description="0-indexed starting character offset in raw text")
    end_char: int = Field(..., description="0-indexed ending character offset in raw text")
    confidence: float = Field(default=0.95, description="Confidence score")

class ClauseSpan(BaseModel):
    clause_type: str = Field(..., description="Type of clause e.g. GOVERNING_LAW, CONFIDENTIALITY")
    text: str = Field(..., description="Full text snippet of the detected clause")
    start_char: int = Field(..., description="Starting character offset in raw text")
    end_char: int = Field(..., description="Ending character offset in raw text")

class ParseSummary(BaseModel):
    total_entities: int
    dates_count: int
    monetary_count: int
    jurisdictions: List[str]
    detected_clause_types: List[str]

class ParseResult(BaseModel):
    filename: str
    content_type: str | None
    text_length: int
    raw_text: str
    entities: List[EntitySpan]
    clauses: List[ClauseSpan]
    summary: ParseSummary

# Clause pattern rules
CLAUSE_PATTERNS = [
    {
        "type": "GOVERNING_LAW",
        "regex": r"(?i)\b(governing\s+law|choice\b.*law|jurisdiction|laws?\s+of\s+(the\s+state\s+of\s+)?[A-Z][a-z]+)\b",
        "keywords": ["governed by", "jurisdiction of", "laws of the state", "choice of law"]
    },
    {
        "type": "CONFIDENTIALITY",
        "regex": r"(?i)\b(confidentiality|non-disclosure|proprietary\s+information|trade\s+secrets)\b",
        "keywords": ["confidential information", "non-disclosure", "proprietary", "keep confidential"]
    },
    {
        "type": "TERMINATION",
        "regex": r"(?i)\b(termination|term\s+and\s+termination|cancellation|right\s+to\s+terminate)\b",
        "keywords": ["terminate", "termination clause", "written notice of cancellation"]
    },
    {
        "type": "LIMITATION_OF_LIABILITY",
        "regex": r"(?i)\b(limitation\s+of\s+liability|consequential\s+damages|maximum\s+liability|cap\s+on\s+liability)\b",
        "keywords": ["limitation of liability", "indirect damages", "aggregate liability"]
    },
    {
        "type": "INDEMNIFICATION",
        "regex": r"(?i)\b(indemnification|indemnify|hold\s+harmless|defend\s+and\s+hold)\b",
        "keywords": ["indemnify", "hold harmless", "defend and hold"]
    },
    {
        "type": "INTELLECTUAL_PROPERTY",
        "regex": r"(?i)\b(intellectual\s+property|ip\s+rights|patents?|trademarks?|copyrights?|ownership\s+of\s+work)\b",
        "keywords": ["intellectual property", "ownership of deliverables", "work for hire"]
    },
    {
        "type": "PAYMENT_TERMS",
        "regex": r"(?i)\b(payment\s+terms?|invoic(e|ing)|fees?\s+and\s+expenses?|due\s+within\s+\d+\s+days)\b",
        "keywords": ["payment terms", "invoicing", "remittance", "fees payable"]
    },
    {
        "type": "DATA_PROTECTION",
        "regex": r"(?i)\b(data\s+protection|privacy\s+policy|gdpr|hipaa|personal\s+data|processing\s+of\s+data)\b",
        "keywords": ["data protection", "gdpr", "hipaa", "personal data", "data controller"]
    }
]

# State & Jurisdiction pattern rules
JURISDICTION_REGEX = re.compile(
    r"(?i)\b(?:governed\s+by\s+(?:and\s+construed\s+in\s+accordance\s+with\s+)?(?:the\s+laws\s+of\s+)?|laws\s+of\s+(?:the\s+State\s+of\s+)?|jurisdiction\s+of\s+(?:the\s+courts\s+of\s+)?)"
    r"((?:State\s+of\s+)?[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)?)\b"
)

def extract_entities_and_clauses(text: str) -> Dict[str, Any]:
    """Run spaCy NER pipeline and clause rule matchers on raw text."""
    doc = nlp(text)
    
    entities: List[EntitySpan] = []
    seen_entity_spans = set()
    
    # 1. spaCy Named Entities (Dates, Money, GPE)
    for ent in doc.ents:
        if ent.label_ in ("DATE", "TIME"):
            category = "DATE"
        elif ent.label_ == "MONEY":
            category = "MONEY"
        elif ent.label_ in ("GPE", "LOC"):
            category = "JURISDICTION"
        else:
            continue
            
        span_key = (ent.start_char, ent.end_char, category)
        if span_key not in seen_entity_spans:
            seen_entity_spans.add(span_key)
            entities.append(EntitySpan(
                text=ent.text.strip(),
                label=category,
                start_char=ent.start_char,
                end_char=ent.end_char,
                confidence=0.95
            ))
            
    # 2. Regex Jurisdiction Matcher
    for match in JURISDICTION_REGEX.finditer(text):
        matched_text = match.group(0).strip()
        matched_state = match.group(1).strip()
        start, end = match.span(1)
        
        span_key = (start, end, "JURISDICTION")
        if span_key not in seen_entity_spans:
            seen_entity_spans.add(span_key)
            entities.append(EntitySpan(
                text=matched_state,
                label="JURISDICTION",
                start_char=start,
                end_char=end,
                confidence=0.98
            ))

    # 3. Clause Classification by Paragraph / Sentence Spans
    clauses: List[ClauseSpan] = []
    seen_clause_spans = set()
    
    # Split raw text into paragraph blocks with offset tracking
    pos = 0
    paragraphs = text.split("\n\n")
    
    for para in paragraphs:
        para_start = text.find(para, pos)
        if para_start == -1:
            para_start = pos
        para_end = para_start + len(para)
        pos = para_end
        
        para_stripped = para.strip()
        if not para_stripped:
            continue
            
        for pattern in CLAUSE_PATTERNS:
            if re.search(pattern["regex"], para_stripped):
                clause_type = pattern["type"]
                clause_key = (para_start, para_end, clause_type)
                
                if clause_key not in seen_clause_spans:
                    seen_clause_spans.add(clause_key)
                    # Snippet max 300 chars for readability
                    snippet = para_stripped[:300] + ("..." if len(para_stripped) > 300 else "")
                    clauses.append(ClauseSpan(
                        clause_type=clause_type,
                        text=snippet,
                        start_char=para_start,
                        end_char=para_end
                    ))

    # Deduplicate overlapping entity spans (keep longer/more specific spans)
    filtered_entities: List[EntitySpan] = []
    # Sort entities by length descending
    entities.sort(key=lambda x: (-(x.end_char - x.start_char), x.start_char))
    
    for ent in entities:
        # Check if this span overlaps with any already selected longer span
        overlap = False
        for kept in filtered_entities:
            if max(ent.start_char, kept.start_char) < min(ent.end_char, kept.end_char):
                overlap = True
                break
        if not overlap:
            filtered_entities.append(ent)

    # Sort final entities by start character offset
    filtered_entities.sort(key=lambda x: x.start_char)
    clauses.sort(key=lambda x: x.start_char)

    # Compute Summary
    jurisdictions_set = sorted(list(set(e.text for e in filtered_entities if e.label == "JURISDICTION")))
    clause_types_set = sorted(list(set(c.clause_type for c in clauses)))
    dates_count = sum(1 for e in filtered_entities if e.label == "DATE")
    monetary_count = sum(1 for e in filtered_entities if e.label == "MONEY")

    summary = ParseSummary(
        total_entities=len(filtered_entities),
        dates_count=dates_count,
        monetary_count=monetary_count,
        jurisdictions=jurisdictions_set,
        detected_clause_types=clause_types_set
    )

    return {
        "entities": [e.model_dump() for e in filtered_entities],
        "clauses": [c.model_dump() for c in clauses],
        "summary": summary.model_dump()
    }
