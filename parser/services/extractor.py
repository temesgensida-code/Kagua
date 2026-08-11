import io
from fastapi import HTTPException, status
import pypdf
import docx

def extract_text_from_pdf(stream_bytes: bytes) -> str:
    """Extract raw text from PDF bytes in memory."""
    try:
        reader = pypdf.PdfReader(io.BytesIO(stream_bytes))
        pages_text = []
        for i, page in enumerate(reader.pages):
            text = page.extract_text()
            if text:
                pages_text.append(text)
        return "\n\n".join(pages_text)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Failed to extract text from PDF file: {str(e)}"
        )

def extract_text_from_docx(stream_bytes: bytes) -> str:
    """Extract raw text from DOCX bytes in memory."""
    try:
        doc = docx.Document(io.BytesIO(stream_bytes))
        paragraphs_text = []
        
        # Extract paragraph text
        for p in doc.paragraphs:
            if p.text.strip():
                paragraphs_text.append(p.text.strip())
                
        # Extract table text if present
        for table in doc.tables:
            for row in table.rows:
                row_text = " | ".join(cell.text.strip() for cell in row.cells if cell.text.strip())
                if row_text:
                    paragraphs_text.append(row_text)
                    
        return "\n\n".join(paragraphs_text)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Failed to extract text from DOCX file: {str(e)}"
        )

def extract_text_from_txt(stream_bytes: bytes) -> str:
    """Extract raw text from TXT / MD bytes in memory."""
    try:
        return stream_bytes.decode('utf-8', errors='replace')
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Failed to decode text file: {str(e)}"
        )

def extract_document_text(filename: str, content_type: str | None, stream_bytes: bytes) -> str:
    """Route document to proper in-memory extractor based on extension and content-type."""
    lower_filename = filename.lower()
    
    if lower_filename.endswith('.pdf') or content_type == 'application/pdf':
        return extract_text_from_pdf(stream_bytes)
    elif lower_filename.endswith('.docx') or content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return extract_text_from_docx(stream_bytes)
    elif lower_filename.endswith('.doc'):
        # Fallback note for legacy binary .doc
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Legacy binary .doc format is not supported directly. Please convert to .docx or .pdf."
        )
    elif lower_filename.endswith(('.txt', '.md')) or (content_type and content_type.startswith('text/')):
        return extract_text_from_txt(stream_bytes)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format: '{filename}'. Only .pdf, .docx, .txt, and .md files are supported."
        )
