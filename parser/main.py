import time
from fastapi import FastAPI, File, UploadFile, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from services.extractor import extract_document_text
from services.ner import extract_entities_and_clauses

app = FastAPI(
    title="Kagua Document Parsing & NER Service",
    description="FastAPI service for in-memory PDF/DOCX text extraction and spaCy NER clause analysis.",
    version="1.0.0"
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
        "service": "Kagua Document Parser API",
        "status": "online",
        "endpoints": {
            "parse": "POST /parse (Upload PDF, DOCX, TXT, MD)"
        }
    }

@app.get("/health")
def health_check():
    return {"status": "ok", "timestamp": time.time()}

@app.post("/parse")
async def parse_document(file: UploadFile = File(...)):
    """
    POST /parse endpoint:
    Accepts PDF or DOCX file (streamed in-memory, never written to disk),
    extracts raw text with pypdf / python-docx, runs spaCy NER to extract entities
    (dates, monetary amounts, jurisdiction, clause types), and returns clean structured
    JSON with exact character offsets in the original text.
    """
    if not file or not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No file uploaded or filename missing."
        )

    # Read binary stream in-memory without writing to disk
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

    # 1. Extract raw text in-memory using pypdf or python-docx
    raw_text = extract_document_text(file.filename, file.content_type, contents)

    if not raw_text or not raw_text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Could not extract readable text from document."
        )

    # 2. Run spaCy NER and Clause Matcher
    ner_result = extract_entities_and_clauses(raw_text)

    # 3. Construct clean structured JSON response
    response_payload = {
        "filename": file.filename,
        "content_type": file.content_type,
        "text_length": len(raw_text),
        "raw_text": raw_text,
        "entities": ner_result["entities"],
        "clauses": ner_result["clauses"],
        "summary": ner_result["summary"]
    }

    return JSONResponse(status_code=200, content=response_payload)
