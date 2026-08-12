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
    _domain_spec: Value,
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
        "Forwarding document stream to FastAPI parser & Privacy-Preserving RAG service...",
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

    let pii_count = parser_response.pii_redacted_count.unwrap_or(0);
    ws_state.broadcast_progress(
        "RAG_PRIVACY_ANONYMIZED",
        &format!("PII Anonymizer redacted {} sensitive user entity instances in memory (0 disk writes)", pii_count),
        Some(json!({ "pii_redacted_count": pii_count })),
    );

    let suggested_domain = parser_response.summary.suggested_domain.clone();
    let detected_jurisdiction = parser_response.summary.detected_jurisdiction.clone();

    // Domain is locked to Ethiopian Labour Proclamation No. 1156/2019
    let final_domain_spec = json!("ethiopian_labour_proclamation");

    ws_state.broadcast_progress(
        "DOMAIN_SELECTED",
        "Using Ethiopian Labour Proclamation No. 1156/2019 compliance rule pack",
        Some(json!({
            "domain": "ethiopian_labour_proclamation",
            "governing_law": "Ethiopian Labour Proclamation No. 1156/2019",
            "jurisdiction": detected_jurisdiction
        })),
    );

    ws_state.broadcast_progress(
        "PARSING_COMPLETED",
        &format!(
            "Extracted {} text chars, {} entities, {} clauses, and RAG facts",
            parser_response.text_length,
            parser_response.entities.len(),
            parser_response.clauses.len()
        ),
        Some(json!({
            "text_length": parser_response.text_length,
            "entities_count": parser_response.entities.len(),
            "clauses_count": parser_response.clauses.len(),
            "suggested_domain": suggested_domain,
            "detected_jurisdiction": detected_jurisdiction,
            "rag_facts": parser_response.rag_facts,
        })),
    );

    // 3. Extract Ethiopian Labour Proclamation facts for Prolog reasoning
    let facts = extract_prolog_facts(&parser_response);

    ws_state.broadcast_progress(
        "FACTS_EXTRACTED",
        &format!("Extracted {} Ethiopian Labour Law compliance facts from document", facts.len()),
        Some(json!({
            "facts": facts,
            "governing_law": "Ethiopian Labour Proclamation No. 1156/2019"
        })),
    );

    ws_state.broadcast_progress(
        "REASONING_PROLOG",
        "Sending facts to SWI-Prolog reasoning engine for violation checking...",
        Some(json!({ "domain": final_domain_spec, "facts": facts })),
    );

    // 4. Forward to SWI-Prolog /reason endpoint
    let reasoner_req = ReasonerRequest {
        domain: final_domain_spec.clone(),
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

    // 5. Zero-copy String Offset Mapping & Statutory Article Citation Mapping
    let raw_text_secure = SecureString::new(parser_response.raw_text.clone());
    let mapped_violations = map_violations_to_offsets(
        raw_text_secure.as_str(),
        &reasoner_response.violations,
        &parser_response.clauses,
        &parser_response.entities,
        parser_response.retrieved_chunks.as_ref(),
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
        domains_checked: final_domain_spec,
        suggested_domain,
        detected_jurisdiction,
        total_violations: mapped_violations.len(),
        critical_count,
        warning_count,
        violations: mapped_violations,
        entities_extracted: parser_response.entities.len(),
        clauses_detected: parser_response.clauses.len(),
        pii_redacted_count: parser_response.pii_redacted_count,
        rag_facts: parser_response.rag_facts,
        fact_provenance: parser_response.fact_provenance,
        proclamation_metadata: parser_response.proclamation_metadata,
        matched_articles: parser_response.retrieved_chunks,
        raw_text: Some(parser_response.raw_text),
    };

    Ok(report)
}

/// Convert extracted NER entities, clauses, and RAG facts into Prolog facts.
/// Scoped exclusively to Ethiopian Labour Proclamation No. 1156/2019.
/// The RAG engine already produces correctly structured facts — this function
/// acts as a thin pass-through, only adding jurisdiction from NER if missing.
fn extract_prolog_facts(parser_res: &ParserResponse) -> Map<String, Value> {
    let mut facts = Map::new();

    // 1. Set domain and governing law
    facts.insert("domain".to_string(), json!("ethiopian_labour_proclamation"));
    facts.insert("governing_law".to_string(), json!("Ethiopian Labour Proclamation No. 1156/2019"));

    // 2. Jurisdiction from NER detection
    if let Some(ref jurisdiction) = parser_res.summary.detected_jurisdiction {
        facts.insert("jurisdiction".to_string(), json!(jurisdiction));
    } else if let Some(jurisdiction) = parser_res.summary.jurisdictions.first() {
        facts.insert("jurisdiction".to_string(), json!(jurisdiction));
    }

    // 3. Merge RAG-extracted Ethiopian Labour Proclamation facts directly
    //    The Python RAG engine (rag_engine.py) already extracts correctly keyed
    //    facts like probation_days, working_hours_per_day, notice_period_days, etc.
    if let Some(ref rag_obj) = parser_res.rag_facts {
        if let Some(obj_map) = rag_obj.as_object() {
            for (k, v) in obj_map {
                facts.insert(k.clone(), v.clone());
            }
        }
    }

    // 4. Map detected Ethiopian clause types to boolean presence facts
    for clause_type in &parser_res.summary.detected_clause_types {
        match clause_type.as_str() {
            "ETHIOPIAN_PROBATION_PERIOD" => {
                facts.insert("has_probation_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_WORKING_HOURS" => {
                facts.insert("has_working_hours_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_OVERTIME" => {
                facts.insert("has_overtime_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_TERMINATION_NOTICE" => {
                facts.insert("has_termination_notice_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_ANNUAL_LEAVE" => {
                facts.insert("has_annual_leave_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_MATERNITY_LEAVE" => {
                facts.insert("has_maternity_leave_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_SICK_LEAVE" => {
                facts.insert("has_sick_leave_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_SEVERANCE_PAY" => {
                facts.insert("has_severance_provision".to_string(), json!(true));
            }
            "ETHIOPIAN_PROHIBITED_ACTS" => {
                facts.insert("has_anti_discrimination".to_string(), json!(true));
            }
            "ETHIOPIAN_MINIMUM_AGE" => {
                facts.insert("has_minimum_age_clause".to_string(), json!(true));
            }
            "ETHIOPIAN_CONTRACT_FORMATION" => {
                facts.insert("has_written_contract_provision".to_string(), json!(true));
            }
            _ => {}
        }
    }

    facts
}

/// Safely extract a substring by Unicode character offsets (not byte offsets).
/// Never panics on multi-byte UTF-8 character boundaries (e.g., bullet points, smart quotes, Amharic text).
fn safe_char_slice(text: &str, start_char: usize, end_char: usize) -> String {
    if text.is_empty() {
        return String::new();
    }
    let char_count = text.chars().count();
    let start = start_char.min(char_count);
    let end = end_char.min(char_count);
    if start >= end {
        return String::new();
    }
    text.chars().skip(start).take(end - start).collect()
}

/// Zero-copy string offset mapping of Prolog violations to exact character slices & statutory citations
fn map_violations_to_offsets(
    raw_text: &str,
    violations: &[PrologViolation],
    clauses: &[ClauseSpan],
    entities: &[EntitySpan],
    retrieved_chunks: Option<&Value>,
) -> Vec<MappedViolation> {
    let mut mapped = Vec::new();

    for v in violations {
        let mut start_char = None;
        let mut end_char = None;
        let mut snippet_str: Option<String> = None;

        // Match violations to Ethiopian Labour Proclamation clause spans
        for clause in clauses {
            let matches_clause = match v.rule.as_str() {
                r if r.contains("Article 11") => clause.clause_type == "ETHIOPIAN_PROBATION_PERIOD",
                r if r.contains("Article 61") => clause.clause_type == "ETHIOPIAN_WORKING_HOURS",
                r if r.contains("Article 14") => clause.clause_type == "ETHIOPIAN_PROHIBITED_ACTS",
                r if r.contains("Article 35") || r.contains("Article 44") => clause.clause_type == "ETHIOPIAN_TERMINATION_NOTICE",
                r if r.contains("Article 77") => clause.clause_type == "ETHIOPIAN_ANNUAL_LEAVE",
                r if r.contains("Article 88") => clause.clause_type == "ETHIOPIAN_MATERNITY_LEAVE",
                r if r.contains("Article 89") || r.contains("Article 90") => clause.clause_type == "ETHIOPIAN_MINIMUM_AGE",
                r if r.contains("Article 85") => clause.clause_type == "ETHIOPIAN_SICK_LEAVE",
                r if r.contains("Article 39") => clause.clause_type == "ETHIOPIAN_SEVERANCE_PAY",
                r if r.contains("Article 67") || r.contains("Article 68") => clause.clause_type == "ETHIOPIAN_OVERTIME",
                r if r.contains("Article 4") || r.contains("Article 6") || r.contains("Article 7") => clause.clause_type == "ETHIOPIAN_CONTRACT_FORMATION",
                _ => false,
            };

            if matches_clause {
                start_char = Some(clause.start_char);
                end_char = Some(clause.end_char);
                let slice = safe_char_slice(raw_text, clause.start_char, clause.end_char);
                if !slice.is_empty() {
                    snippet_str = Some(slice);
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

        // Fallback: safe slice of raw_text prefix
        if start_char.is_none() && !raw_text.is_empty() {
            let slice = safe_char_slice(raw_text, 0, 200);
            let char_count = raw_text.chars().count();
            start_char = Some(0);
            end_char = Some(200.min(char_count));
            snippet_str = Some(slice);
        }

        // Attach statutory article citation & exact Proclamation No. 1156/2019 statutory text
        let (article_citation, statutory_text) = lookup_statutory_citation(&v.rule, retrieved_chunks);

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
            article_citation,
            statutory_text,
        });
    }

    mapped
}

/// Lookup statutory article citation and exact text for Ethiopian Labour Proclamation No. 1156/2019
fn lookup_statutory_citation(
    rule: &str,
    retrieved_chunks: Option<&Value>,
) -> (Option<String>, Option<String>) {
    // 1. Check retrieved_chunks from Python RAG response
    if let Some(chunks) = retrieved_chunks.and_then(|v| v.as_array()) {
        for chk in chunks {
            if chk.get("source").and_then(|s| s.as_str()) == Some("ethiopian_labour_proclamation_1156_2019") {
                let art_num = chk.get("article_number").and_then(|n| n.as_i64()).unwrap_or(0);
                let art_str = format!("Article {}", art_num);
                if rule.contains(&art_str) {
                    let title = chk.get("article_title").and_then(|s| s.as_str()).unwrap_or("");
                    let snippet = chk.get("snippet").and_then(|s| s.as_str()).unwrap_or("");
                    let citation = format!("Ethiopian Labour Proclamation No. 1156/2019 - Article {} ({})", art_num, title);
                    return (Some(citation), Some(snippet.to_string()));
                }
            }
        }
    }

    // 2. Fallback statutory lookup table for Ethiopian Labour Proclamation No. 1156/2019
    let (citation, statutory) = match rule {
        r if r.contains("Article 11") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 11(3)",
            "Article 11(3): The period of probation shall be fixed by mutual agreement of the parties; provided, however, that it shall not exceed 60 (sixty) working days."
        ),
        r if r.contains("Article 61") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 61(1)",
            "Article 61(1): Normal hours of work shall not exceed 8 hours a day or 48 hours a week."
        ),
        r if r.contains("Article 67") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 67",
            "Article 67: Overtime work shall not exceed 2 hours in a day, 20 hours in a month or 100 hours in a year."
        ),
        r if r.contains("Article 77") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 77(1)",
            "Article 77(1): An worker shall be entitled to uninterrupted paid annual leave of 16 (sixteen) working days for the first year of service."
        ),
        r if r.contains("Article 88") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 88(2-3)",
            "Article 88(2-3): A pregnant worker shall be granted a period of 30 consecutive days of leave with pay preceding her presumed date of confinement and a period of 90 consecutive days of leave post confinement."
        ),
        r if r.contains("Article 85") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 85",
            "Article 85: Where a worker, after having completed probation, rendered service for not less than 6 months, sick leave granted shall not exceed 6 months."
        ),
        r if r.contains("Article 35") || r.contains("Article 44") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Articles 35 & 44",
            "Articles 35 & 44: A contract of employment may be terminated by written notice given by one of the parties to the other. Minimum notice period is 30 days."
        ),
        r if r.contains("Article 39") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 39",
            "Article 39: A worker who has completed probation and whose contract is terminated under lawful grounds shall be entitled to severance pay of thirty days' wages for the first year of service."
        ),
        r if r.contains("Article 14") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 14(1)(f) & (h)",
            "Article 14: It shall be unlawful for an employer to discriminate between workers on grounds of sex, religion, race, or status, or commit sexual harassment or sexual assault."
        ),
        r if r.contains("Article 89") || r.contains("Article 90") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Articles 89 & 90",
            "Article 89(1): It is prohibited to employ persons under 15 years of age. Article 90: Normal daily working hours for young workers (ages 15-18) shall not exceed 7 hours per day."
        ),
        r if r.contains("Article 6") => (
            "Ethiopian Labour Proclamation No. 1156/2019 - Article 6",
            "Article 6: Where a contract of employment is not made in writing, the employer shall issue a signed letter of employment containing essential terms within 15 days."
        ),
        _ => return (None, None),
    };

    (Some(citation.to_string()), Some(statutory.to_string()))
}
