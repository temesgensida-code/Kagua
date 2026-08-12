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
    clause_type: str = Field(..., description="Type of Ethiopian Labour Proclamation clause e.g. PROBATION_PERIOD, WORKING_HOURS")
    text: str = Field(..., description="Full text snippet of the detected clause")
    start_char: int = Field(..., description="Starting character offset in raw text")
    end_char: int = Field(..., description="Ending character offset in raw text")

class ParseSummary(BaseModel):
    total_entities: int
    dates_count: int
    monetary_count: int
    jurisdictions: List[str]
    detected_clause_types: List[str]
    suggested_domain: str = Field(default="ethiopian_labour_proclamation", description="Ethiopian Labour Proclamation rule pack")
    detected_jurisdiction: str | None = Field(default="Federal Democratic Republic of Ethiopia", description="Governing state or jurisdiction")

class ParseResult(BaseModel):
    filename: str
    content_type: str | None
    text_length: int
    raw_text: str
    entities: List[EntitySpan]
    clauses: List[ClauseSpan]
    summary: ParseSummary

# Ethiopian Labour Proclamation No. 1156/2019 Clause Pattern Matchers
CLAUSE_PATTERNS = [
    {
        "type": "ETHIOPIAN_PROBATION_PERIOD",
        "regex": r"(?i)\b(probation|probationary\s+period|trial\s+period|testing\s+suitability|60\s+working\s+days)\b",
        "keywords": ["probation period", "trial period", "60 working days", "Article 11"]
    },
    {
        "type": "ETHIOPIAN_WORKING_HOURS",
        "regex": r"(?i)\b(working\s+hours|normal\s+hours\s+of\s+work|8\s+hours\s+a\s+day|48\s+hours\s+a\s+week)\b",
        "keywords": ["hours of work", "8 hours a day", "48 hours a week", "Article 61"]
    },
    {
        "type": "ETHIOPIAN_OVERTIME",
        "regex": r"(?i)\b(overtime|extra\s+hours|overtime\s+rates?|1\.25|1\.5|1\.75|2\.0|2\.5|weekly\s+rest|public\s+holiday)\b",
        "keywords": ["overtime", "overtime rate", "Article 67", "Article 68"]
    },
    {
        "type": "ETHIOPIAN_TERMINATION_NOTICE",
        "regex": r"(?i)\b(notice\s+of\s+termination|notice\s+period|prior\s+notice|written\s+notice\s+of\s+cancellation|30\s+days\s+notice)\b",
        "keywords": ["notice period", "termination notice", "Article 35", "Article 44"]
    },
    {
        "type": "ETHIOPIAN_ANNUAL_LEAVE",
        "regex": r"(?i)\b(annual\s+leave|paid\s+leave|16\s+working\s+days|vacation\s+leave)\b",
        "keywords": ["annual leave", "16 working days", "Article 77"]
    },
    {
        "type": "ETHIOPIAN_MATERNITY_LEAVE",
        "regex": r"(?i)\b(maternity\s+leave|pregnancy\s+leave|prenatal|postnatal|120\s+days|30\s+days\s+prenatal)\b",
        "keywords": ["maternity leave", "120 consecutive days", "Article 88"]
    },
    {
        "type": "ETHIOPIAN_SICK_LEAVE",
        "regex": r"(?i)\b(sick\s+leave|medical\s+leave|incapacity|6\s+months\s+sick\s+leave)\b",
        "keywords": ["sick leave", "6 months", "Article 85"]
    },
    {
        "type": "ETHIOPIAN_SEVERANCE_PAY",
        "regex": r"(?i)\b(severance\s+pay|termination\s+compensation|30\s+days\s+wages?|monthly\s+wage)\b",
        "keywords": ["severance pay", "Article 39"]
    },
    {
        "type": "ETHIOPIAN_PROHIBITED_ACTS",
        "regex": r"(?i)\b(prohibited\s+acts|discrimination|sexual\s+harassment|sexual\s+violence|forced\s+labo?ur|unlawful\s+act)\b",
        "keywords": ["prohibited acts", "discrimination", "sexual harassment", "Article 14"]
    },
    {
        "type": "ETHIOPIAN_MINIMUM_AGE",
        "regex": r"(?i)\b(minimum\s+age|child\s+labo?ur|young\s+worker|15\s+years\s+of\s+age)\b",
        "keywords": ["minimum age", "young worker", "Article 89"]
    },
    {
        "type": "ETHIOPIAN_CONTRACT_FORMATION",
        "regex": r"(?i)\b(contract\s+of\s+employment|written\s+contract|letter\s+of\s+employment|15\s+days)\b",
        "keywords": ["contract of employment", "Article 4", "Article 6", "Article 7"]
    }
]

# State & Jurisdiction pattern rules for Ethiopia
JURISDICTION_REGEX = re.compile(
    r"(?i)\b(?:governed\s+by\s+(?:the\s+laws\s+of\s+)?|jurisdiction\s+of\s+(?:the\s+courts\s+of\s+)?)"
    r"(Ethiopia|Federal\s+Democratic\s+Republic\s+of\s+Ethiopia|Addis\s+Ababa|Dire\s+Dawa)"
)

def detect_suggested_domain_and_jurisdiction(text: str) -> tuple[str, str | None]:
    """
    Scans document text and sets the suggested compliance domain to ethiopian_labour_proclamation
    and defaults jurisdiction to Ethiopia / Federal Democratic Republic of Ethiopia.
    """
    first_500_words = " ".join(text.split()[:500])

    detected_jurisdiction = "Federal Democratic Republic of Ethiopia"
    match = JURISDICTION_REGEX.search(first_500_words)
    if match:
        detected_jurisdiction = match.group(1).strip()

    suggested_domain = "ethiopian_labour_proclamation"
    return suggested_domain, detected_jurisdiction

def extract_entities_and_clauses(text: str) -> Dict[str, Any]:
    """Run spaCy NER pipeline and Ethiopian Labour Proclamation clause matchers on raw text."""
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

    # 3. Clause Classification by Paragraph Spans
    clauses: List[ClauseSpan] = []
    seen_clause_spans = set()

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
                    snippet = para_stripped[:300] + ("..." if len(para_stripped) > 300 else "")
                    clauses.append(ClauseSpan(
                        clause_type=clause_type,
                        text=snippet,
                        start_char=para_start,
                        end_char=para_end
                    ))

    # Deduplicate overlapping entity spans
    filtered_entities: List[EntitySpan] = []
    entities.sort(key=lambda x: (-(x.end_char - x.start_char), x.start_char))

    for ent in entities:
        overlap = False
        for kept in filtered_entities:
            if max(ent.start_char, kept.start_char) < min(ent.end_char, kept.end_char):
                overlap = True
                break
        if not overlap:
            filtered_entities.append(ent)

    filtered_entities.sort(key=lambda x: x.start_char)
    clauses.sort(key=lambda x: x.start_char)

    suggested_domain, detected_jurisdiction = detect_suggested_domain_and_jurisdiction(text)

    jurisdictions_set = sorted(list(set(e.text for e in filtered_entities if e.label == "JURISDICTION")))
    if detected_jurisdiction and detected_jurisdiction not in jurisdictions_set:
        jurisdictions_set.insert(0, detected_jurisdiction)

    clause_types_set = sorted(list(set(c.clause_type for c in clauses)))
    dates_count = sum(1 for e in filtered_entities if e.label == "DATE")
    monetary_count = sum(1 for e in filtered_entities if e.label == "MONEY")

    summary = ParseSummary(
        total_entities=len(filtered_entities),
        dates_count=dates_count,
        monetary_count=monetary_count,
        jurisdictions=jurisdictions_set,
        detected_clause_types=clause_types_set,
        suggested_domain=suggested_domain,
        detected_jurisdiction=detected_jurisdiction
    )

    return {
        "entities": [e.model_dump() for e in filtered_entities],
        "clauses": [c.model_dump() for c in clauses],
        "summary": summary.model_dump()
    }

