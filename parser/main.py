import time
from fastapi import FastAPI, File, UploadFile, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from services.extractor import extract_document_text
from services.ner import extract_entities_and_clauses
from services.rag_engine import extract_rag_compliance_facts, anonymize_text, proclamation_corpus

app = FastAPI(
    title="Kagua Ethiopian Labour Proclamation Parsing & RAG Service",
    description="FastAPI service for in-memory document parsing, spaCy NER, and privacy-preserving RAG compliance extraction against Ethiopian Labour Proclamation No. 1156/2019.",
    version="2.0.0"
)

# Enable CORS for frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_FILE_SIZE_BYTES = 20 * 1024 * 1024  # 20MB limit

@app.get("/")
def read_root():
    return {
        "service": "Kagua Ethiopian Labour Proclamation Parser & RAG Engine API",
        "target_legal_framework": proclamation_corpus.metadata,
        "status": "online",
        "endpoints": {
            "parse": "POST /parse (Upload employment contract for Ethiopian Labour Proclamation NER & RAG fact extraction)",
            "rag_parse": "POST /rag-parse (Dedicated Ethiopian Labour Proclamation RAG fact extractor)"
        }
    }

@app.get("/health")
def health_check():
    return {"status": "ok", "timestamp": time.time()}

@app.post("/parse")
async def parse_document(file: UploadFile = File(...)):
    """
    POST /parse endpoint:
    1. Streams file into RAM (0 disk writes).
    2. Extracts raw text with pypdf / python-docx.
    3. Runs spaCy NER & Ethiopian Labour Proclamation clause matcher.
    4. Executes Privacy-Preserving Ethiopian Labour Law RAG Pipeline:
       - De-identifies sensitive user PII.
       - Retrieves matched Articles from parser/jsons/labour_proclamation_1156_2019.json.
       - Synthesizes structured Ethiopian Labour Law Prolog facts for reasoning.
    """
    if not file or not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No file uploaded or filename missing."
        )

    try:
        contents = await file.read()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to read uploaded file stream: {str(e)}"
        )

    if len(contents) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty (0 bytes)."
        )

    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size exceeds maximum threshold of {MAX_FILE_SIZE_BYTES // (1024 * 1024)}MB."
        )

    # 1. Extract raw text in-memory
    raw_text = extract_document_text(file.filename, file.content_type, contents)

    if not raw_text or not raw_text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Could not extract readable text from document."
        )

    # 2. Run spaCy NER & Ethiopian Clause Matcher
    ner_result = extract_entities_and_clauses(raw_text)

    # 3. Run Privacy-Preserving Ethiopian Labour Law RAG Engine
    rag_result = extract_rag_compliance_facts(raw_text)

    # 4. Construct response payload
    response_payload = {
        "filename": file.filename,
        "content_type": file.content_type,
        "text_length": len(raw_text),
        "raw_text": raw_text,
        "entities": ner_result["entities"],
        "clauses": ner_result["clauses"],
        "summary": ner_result["summary"],
        "rag_facts": rag_result["prolog_facts"],
        "fact_provenance": rag_result.get("fact_provenance", {}),
        "pii_redacted_count": rag_result["pii_redacted_count"],
        "retrieved_chunks": rag_result["retrieved_chunks"],
        "proclamation_metadata": rag_result["proclamation_metadata"]
    }

    return JSONResponse(status_code=200, content=response_payload)

@app.post("/rag-parse")
async def rag_parse_document(file: UploadFile = File(...)):
    """
    POST /rag-parse endpoint:
    Dedicated RAG endpoint returning anonymized text, PII redaction stats, retrieved Ethiopian Labour Proclamation chunks,
    and structured Prolog facts.
    """
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded.")

    contents = await file.read()
    raw_text = extract_document_text(file.filename, file.content_type, contents)
    if not raw_text or not raw_text.strip():
        raise HTTPException(status_code=422, detail="Empty or unreadable document.")

    sanitized_text, pii_map = anonymize_text(raw_text)
    rag_result = extract_rag_compliance_facts(raw_text)

    return JSONResponse(status_code=200, content={
        "filename": file.filename,
        "pii_redacted_count": len(pii_map),
        "redacted_tokens": list(pii_map.values()),
        "sanitized_text_preview": sanitized_text[:300],
        "prolog_facts": rag_result["prolog_facts"],
        "retrieved_chunks": rag_result["retrieved_chunks"],
        "proclamation_metadata": rag_result["proclamation_metadata"]
    })

