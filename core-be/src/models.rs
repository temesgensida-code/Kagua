use serde::{Deserialize, Serialize};

/// Entity returned from Python `/parse` endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntitySpan {
    pub text: String,
    pub label: String,
    pub start_char: usize,
    pub end_char: usize,
    pub confidence: f64,
}

/// Clause returned from Python `/parse` endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClauseSpan {
    pub clause_type: String,
    pub text: String,
    pub start_char: usize,
    pub end_char: usize,
}

/// Summary returned from Python `/parse` endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParseSummary {
    pub total_entities: usize,
    pub dates_count: usize,
    pub monetary_count: usize,
    pub jurisdictions: Vec<String>,
    pub detected_clause_types: Vec<String>,
    pub suggested_domain: Option<String>,
    pub detected_jurisdiction: Option<String>,
}

/// Full JSON payload returned from FastAPI `/parse`
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParserResponse {
    pub filename: String,
    pub content_type: Option<String>,
    pub text_length: usize,
    pub raw_text: String,
    pub entities: Vec<EntitySpan>,
    pub clauses: Vec<ClauseSpan>,
    pub summary: ParseSummary,
    pub rag_facts: Option<serde_json::Value>,
    pub pii_redacted_count: Option<usize>,
    pub retrieved_chunks: Option<serde_json::Value>,
    pub proclamation_metadata: Option<serde_json::Value>,
}

/// Request sent to SWI-Prolog `/reason` endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReasonerRequest {
    pub domain: serde_json::Value,
    pub facts: serde_json::Map<String, serde_json::Value>,
}

/// Individual raw violation from SWI-Prolog
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrologViolation {
    pub domain: String,
    pub rule: String,
    pub title: String,
    pub severity: String,
    pub description: String,
    pub recommendation: String,
}

/// Response returned from SWI-Prolog `/reason` endpoint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReasonerResponse {
    pub status: String,
    pub domain: serde_json::Value,
    pub violations_count: usize,
    pub violations: Vec<PrologViolation>,
}

/// Mapped violation with character offset slice snippet in the original text
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MappedViolation {
    pub domain: String,
    pub rule: String,
    pub title: String,
    pub severity: String,
    pub description: String,
    pub recommendation: String,
    pub snippet: Option<String>,
    pub start_char: Option<usize>,
    pub end_char: Option<usize>,
}

/// Final comprehensive analysis report returned by `POST /analyze`
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisReport {
    pub filename: String,
    pub text_length: usize,
    pub domains_checked: serde_json::Value,
    pub suggested_domain: Option<String>,
    pub detected_jurisdiction: Option<String>,
    pub total_violations: usize,
    pub critical_count: usize,
    pub warning_count: usize,
    pub violations: Vec<MappedViolation>,
    pub entities_extracted: usize,
    pub clauses_detected: usize,
    pub pii_redacted_count: Option<usize>,
    pub rag_facts: Option<serde_json::Value>,
    pub proclamation_metadata: Option<serde_json::Value>,
    pub matched_articles: Option<serde_json::Value>,
}

/// WebSocket Progress Stage Event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProgressEvent {
    pub stage: String,
    pub message: String,
    pub details: Option<serde_json::Value>,
    pub timestamp_ms: u64,
}
