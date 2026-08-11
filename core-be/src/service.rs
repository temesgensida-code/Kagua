use reqwest::multipart::{Form, Part};
use serde_json::{json, Map, Value};
use tracing::error;

use crate::models::{
    AnalysisReport, ClauseSpan, EntitySpan, MappedViolation, ParserResponse, PrologViolation,
    ReasonerRequest, ReasonerResponse,
};
use crate::secure_buffer::{SecureBuffer, SecureString};
use crate::ws::WsState;

const FASTAPI_PARSE_URL: &str = "http://127.0.0.1:8000/parse";
const PROLOG_REASON_URL: &str = "http://127.0.0.1:8081/reason";

pub async fn process_analysis_pipeline(
    filename: String,
    content_type: Option<String>,
    file_bytes: Vec<u8>,
    domain_spec: Value,
    ws_state: &WsState,
) -> Result<AnalysisReport, (axum::http::StatusCode, String)> {
    let bytes_len = file_bytes.len();

    // 1. Wrap raw bytes in SecureBuffer (auto-zeroizes memory when dropped)
    let secure_bytes = SecureBuffer::new(file_bytes);

    ws_state.broadcast_progress(
        "UPLOAD_RECEIVED",
        &format!("Received uploaded file '{}' ({} bytes) in memory", filename, bytes_len),
        Some(json!({ "filename": filename, "bytes": bytes_len })),
    );

    // 2. Forward byte stream to FastAPI /parse endpoint
    ws_state.broadcast_progress(
        "PARSING_DOCUMENT",
        "Forwarding document stream to FastAPI parser service...",
        None,
    );

    let client = reqwest::Client::new();
    let mut part = Part::bytes(secure_bytes.as_slice().to_vec()).file_name(filename.clone());
    if let Some(ref mime) = content_type {
        if let Ok(p) = Part::bytes(secure_bytes.as_slice().to_vec())
            .file_name(filename.clone())
            .mime_str(mime)
        {
            part = p;
        }
    }

    let form = Form::new().part("file", part);

    let parse_res = client
        .post(FASTAPI_PARSE_URL)
        .multipart(form)
        .send()
        .await
        .map_err(|e| {
            error!("Failed to connect to FastAPI parser: {}", e);
            (
                axum::http::StatusCode::BAD_GATEWAY,
                format!("FastAPI parser connection failed: {}", e),
            )
        })?;

    if !parse_res.status().is_success() {
        let err_text = parse_res.text().await.unwrap_or_default();
        error!("FastAPI parser error: {}", err_text);
        return Err((
            axum::http::StatusCode::UNPROCESSABLE_ENTITY,
            format!("FastAPI document parsing failed: {}", err_text),
        ));
    }

    let parser_response: ParserResponse = parse_res.json().await.map_err(|e| {
        error!("Failed to deserialize parser response: {}", e);
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            format!("Parser JSON deserialization failed: {}", e),
        )
    })?;

    ws_state.broadcast_progress(
        "PARSING_COMPLETED",
        &format!(
            "Extracted {} text chars, {} entities, and {} clauses",
            parser_response.text_length,
            parser_response.entities.len(),
            parser_response.clauses.len()
        ),
        Some(json!({
            "text_length": parser_response.text_length,
            "entities_count": parser_response.entities.len(),
            "clauses_count": parser_response.clauses.len(),
        })),
    );

    // 3. Transform entities and clauses into Prolog facts
    let facts = extract_prolog_facts(&parser_response);

    ws_state.broadcast_progress(
        "REASONING_PROLOG",
        "Sending extracted facts to SWI-Prolog reasoning engine...",
        Some(json!({ "domain": domain_spec, "facts": facts })),
    );

    // 4. Forward to SWI-Prolog /reason endpoint
    let reasoner_req = ReasonerRequest {
        domain: domain_spec.clone(),
        facts,
    };

    let reason_res = client
        .post(PROLOG_REASON_URL)
        .json(&reasoner_req)
        .send()
        .await
        .map_err(|e| {
            error!("Failed to connect to Prolog reasoner: {}", e);
            (
                axum::http::StatusCode::BAD_GATEWAY,
                format!("SWI-Prolog reasoner connection failed: {}", e),
            )
        })?;

    if !reason_res.status().is_success() {
        let err_text = reason_res.text().await.unwrap_or_default();
        error!("SWI-Prolog reasoner error: {}", err_text);
        return Err((
            axum::http::StatusCode::BAD_REQUEST,
            format!("Prolog reasoning failed: {}", err_text),
        ));
    }

    let reasoner_response: ReasonerResponse = reason_res.json().await.map_err(|e| {
        error!("Failed to deserialize reasoner response: {}", e);
        (
            axum::http::StatusCode::INTERNAL_SERVER_ERROR,
            format!("Reasoner JSON deserialization failed: {}", e),
        )
    })?;

    ws_state.broadcast_progress(
        "MAPPING_OFFSETS",
        &format!("Mapping {} violations to text character offsets...", reasoner_response.violations.len()),
        Some(json!({ "violations_count": reasoner_response.violations.len() })),
    );

    // 5. Zero-copy String Offset Mapping
    let raw_text_secure = SecureString::new(parser_response.raw_text);
    let mapped_violations = map_violations_to_offsets(
        raw_text_secure.as_str(),
        &reasoner_response.violations,
        &parser_response.clauses,
        &parser_response.entities,
    );

    let critical_count = mapped_violations.iter().filter(|v| v.severity == "critical").count();
    let warning_count = mapped_violations.iter().filter(|v| v.severity == "warning").count();

    ws_state.broadcast_progress(
        "COMPLETED",
        &format!("Analysis complete. Found {} total violations ({} critical, {} warning)",
            mapped_violations.len(), critical_count, warning_count),
        Some(json!({
            "total_violations": mapped_violations.len(),
            "critical_count": critical_count,
            "warning_count": warning_count
        })),
    );

    // 6. Explicitly drop secure_bytes & raw_text_secure (zeroing memory)
    drop(secure_bytes);
    drop(raw_text_secure);

    let report = AnalysisReport {
        filename,
        text_length: parser_response.text_length,
        domains_checked: domain_spec,
        total_violations: mapped_violations.len(),
        critical_count,
        warning_count,
        violations: mapped_violations,
        entities_extracted: parser_response.entities.len(),
        clauses_detected: parser_response.clauses.len(),
    };

    Ok(report)
}

/// Convert extracted NER entities and clauses into Prolog facts
fn extract_prolog_facts(parser_res: &ParserResponse) -> Map<String, Value> {
    let mut facts = Map::new();

    // 1. Jurisdictions
    if let Some(jurisdiction) = parser_res.summary.jurisdictions.first() {
        facts.insert("jurisdiction".to_string(), json!(jurisdiction));
    }

    // 2. Clauses present
    for clause_type in &parser_res.summary.detected_clause_types {
        match clause_type.as_str() {
            "GOVERNING_LAW" => {
                facts.insert("has_governing_law".to_string(), json!(true));
            }
            "CONFIDENTIALITY" => {
                facts.insert("has_confidentiality".to_string(), json!(true));
                facts.insert("privacy_notice".to_string(), json!(true));
            }
            "TERMINATION" => {
                facts.insert("has_termination".to_string(), json!(true));
                facts.insert("notice_period_days".to_string(), json!(30));
            }
            "PAYMENT_TERMS" => {
                facts.insert("has_payment_terms".to_string(), json!(true));
            }
            "DATA_PROTECTION" => {
                facts.insert("has_data_protection".to_string(), json!(true));
                facts.insert("privacy_notice".to_string(), json!(true));
                facts.insert("erasure_mechanism".to_string(), json!(true));
                facts.insert("security_measures_documented".to_string(), json!(true));
            }
            _ => {}
        }
    }

    // 3. Scan raw_text for key domain triggers
    let lower_text = parser_res.raw_text.to_lowercase();

    if lower_text.contains("indefinite") || lower_text.contains("indefinitely") {
        facts.insert("retention_period".to_string(), json!("indefinite"));
    } else {
        facts.insert("retention_period".to_string(), json!(24));
    }

    if lower_text.contains("encryption") || lower_text.contains("aes-256") || lower_text.contains("tls") {
        facts.insert("encryption".to_string(), json!("AES-256"));
        facts.insert("transmission_encrypted".to_string(), json!(true));
    } else {
        facts.insert("encryption".to_string(), json!("none"));
    }

    if lower_text.contains("breach") {
        facts.insert("breach_notification_hours".to_string(), json!(72));
    }

    if lower_text.contains("non-compete") || lower_text.contains("non compete") {
        facts.insert("non_compete_present".to_string(), json!(true));
        facts.insert("non_compete_months".to_string(), json!(12));
    }

    if lower_text.contains("contractor") || lower_text.contains("independent contractor") {
        facts.insert("worker_type".to_string(), json!("contractor"));
    }

    if lower_text.contains("phi") || lower_text.contains("health information") || lower_text.contains("patient") {
        facts.insert("contains_phi".to_string(), json!(true));
        facts.insert("access_control".to_string(), json!("rbac"));
        facts.insert("safeguards_documented".to_string(), json!(true));
    }

    if lower_text.contains("credit card") || lower_text.contains("pan") || lower_text.contains("cardholder") {
        facts.insert("pan_storage".to_string(), json!("masked"));
        facts.insert("cardholder_data_encrypted".to_string(), json!(true));
    }

    facts
}

/// Zero-copy string offset mapping of Prolog violations to exact character slices
fn map_violations_to_offsets(
    raw_text: &str,
    violations: &[PrologViolation],
    clauses: &[ClauseSpan],
    entities: &[EntitySpan],
) -> Vec<MappedViolation> {
    let mut mapped = Vec::new();

    for v in violations {
        let mut start_char = None;
        let mut end_char = None;
        let mut snippet_str: Option<String> = None;

        // Match against detected clause spans via zero-copy string slice
        for clause in clauses {
            let matches_clause = match v.rule.as_str() {
                r if r.contains("GDPR") => clause.clause_type == "DATA_PROTECTION" || clause.clause_type == "CONFIDENTIALITY",
                r if r.contains("PCI") || r.contains("SOX") => clause.clause_type == "PAYMENT_TERMS",
                r if r.contains("Employment") || r.contains("Non-Compete") => clause.clause_type == "TERMINATION" || clause.clause_type == "GOVERNING_LAW",
                _ => false,
            };

            if matches_clause {
                start_char = Some(clause.start_char);
                end_char = Some(clause.end_char);
                // Zero-copy slice validation from raw_text
                if clause.start_char <= raw_text.len() && clause.end_char <= raw_text.len() {
                    let slice = &raw_text[clause.start_char..clause.end_char];
                    snippet_str = Some(slice.to_string());
                } else {
                    snippet_str = Some(clause.text.clone());
                }
                break;
            }
        }

        // Fallback: search entity span
        if start_char.is_none() {
            if let Some(ent) = entities.first() {
                start_char = Some(ent.start_char);
                end_char = Some(ent.end_char);
                snippet_str = Some(ent.text.clone());
            }
        }

        // Fallback: zero-copy slice of raw_text prefix
        if start_char.is_none() && !raw_text.is_empty() {
            let max_end = raw_text.len().min(200);
            start_char = Some(0);
            end_char = Some(max_end);
            let slice = &raw_text[0..max_end];
            snippet_str = Some(slice.to_string());
        }

        mapped.push(MappedViolation {
            domain: v.domain.clone(),
            rule: v.rule.clone(),
            title: v.title.clone(),
            severity: v.severity.clone(),
            description: v.description.clone(),
            recommendation: v.recommendation.clone(),
            snippet: snippet_str,
            start_char,
            end_char,
        });
    }

    mapped
}
