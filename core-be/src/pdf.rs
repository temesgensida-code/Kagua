use printpdf::*;
use std::io::BufWriter;
use crate::models::AnalysisReport;

pub fn generate_audit_pdf(report: &AnalysisReport) -> Result<Vec<u8>, String> {
    // 1. Calculate Compliance Score (100 base, -25 per critical, -10 per warning)
    let base_score: i32 = 100;
    let penalty = (report.critical_count as i32 * 25) + (report.warning_count as i32 * 10);
    let compliance_score = (base_score - penalty).clamp(0, 100);

    let (score_category, score_color) = if compliance_score >= 80 {
        ("HIGH COMPLIANCE (LOW RISK)", (0.1, 0.7, 0.3)) // Green
    } else if compliance_score >= 50 {
        ("MODERATE RISK (ACTION REQUIRED)", (0.9, 0.6, 0.1)) // Amber
    } else {
        ("CRITICAL NON-COMPLIANCE (HIGH RISK)", (0.8, 0.1, 0.1)) // Red
    };

    // 2. Initialize PDF Document (A4 size: 210mm x 297mm)
    let (doc, page1, layer1) = PdfDocument::new(
        format!("Kagua Audit Report - {}", report.filename),
        Mm(210.0),
        Mm(297.0),
        "Layer 1",
    );

    let mut current_layer = doc.get_page(page1).get_layer(layer1);

    // Built-in Helvetica fonts
    let font_bold = doc.add_builtin_font(BuiltinFont::HelveticaBold).map_err(|e| e.to_string())?;
    let font_regular = doc.add_builtin_font(BuiltinFont::Helvetica).map_err(|e| e.to_string())?;

    let mut y_pos = Mm(280.0);

    // -------------------------------------------------------------------------
    // Header Title & Subtitle
    // -------------------------------------------------------------------------
    current_layer.use_text("KAGUA COMPLIANCE AUDIT REPORT", 18.0, Mm(15.0), y_pos, &font_bold);
    y_pos -= Mm(7.0);

    current_layer.use_text("Automated Regulatory Reasoning & Offset Audit Summary", 10.0, Mm(15.0), y_pos, &font_regular);
    y_pos -= Mm(8.0);

    // Divider
    current_layer.use_text("________________________________________________________________________________________", 9.0, Mm(15.0), y_pos, &font_regular);
    y_pos -= Mm(10.0);

    // -------------------------------------------------------------------------
    // Document Metadata
    // -------------------------------------------------------------------------
    current_layer.use_text(format!("Document: {}", report.filename), 10.0, Mm(15.0), y_pos, &font_bold);
    y_pos -= Mm(5.5);

    let domains_str = report.domains_checked.to_string();
    current_layer.use_text(format!("Domains Evaluated: {}", domains_str), 9.0, Mm(15.0), y_pos, &font_regular);
    y_pos -= Mm(5.0);

    if let Some(ref jurisdiction) = report.detected_jurisdiction {
        current_layer.use_text(format!("Governing Jurisdiction: {}", jurisdiction), 9.0, Mm(15.0), y_pos, &font_regular);
        y_pos -= Mm(5.0);
    }

    if let Some(ref suggested) = report.suggested_domain {
        current_layer.use_text(format!("Auto-Selected Domain: {}", suggested), 9.0, Mm(15.0), y_pos, &font_regular);
        y_pos -= Mm(5.0);
    }

    current_layer.use_text(
        format!("Total Entities Extracted: {}  |  Clauses Detected: {}", report.entities_extracted, report.clauses_detected),
        9.0,
        Mm(15.0),
        y_pos,
        &font_regular,
    );
    y_pos -= Mm(10.0);

    // -------------------------------------------------------------------------
    // Compliance Score Card (Red / Amber / Green)
    // -------------------------------------------------------------------------
    current_layer.use_text(format!("COMPLIANCE SCORE: {} / 100", compliance_score), 14.0, Mm(15.0), y_pos, &font_bold);
    y_pos -= Mm(6.0);

    current_layer.set_fill_color(Color::Rgb(Rgb::new(score_color.0, score_color.1, score_color.2, None)));
    current_layer.use_text(format!("Status: {}", score_category), 11.0, Mm(15.0), y_pos, &font_bold);
    current_layer.set_fill_color(Color::Rgb(Rgb::new(0.0, 0.0, 0.0, None))); // Reset black

    y_pos -= Mm(5.5);
    current_layer.use_text(
        format!("Total Violations: {}  (Critical: {}, Warning: {})", report.total_violations, report.critical_count, report.warning_count),
        9.5,
        Mm(15.0),
        y_pos,
        &font_regular,
    );
    y_pos -= Mm(8.0);

    // Divider
    current_layer.use_text("________________________________________________________________________________________", 9.0, Mm(15.0), y_pos, &font_regular);
    y_pos -= Mm(10.0);

    // -------------------------------------------------------------------------
    // Categorized Violations Section
    // -------------------------------------------------------------------------
    current_layer.use_text("CATEGORIZED VIOLATION FINDINGS", 12.0, Mm(15.0), y_pos, &font_bold);
    y_pos -= Mm(8.0);

    if report.violations.is_empty() {
        current_layer.set_fill_color(Color::Rgb(Rgb::new(0.1, 0.7, 0.3, None)));
        current_layer.use_text("✓ No compliance violations detected in the analyzed document.", 10.0, Mm(15.0), y_pos, &font_bold);
        current_layer.set_fill_color(Color::Rgb(Rgb::new(0.0, 0.0, 0.0, None)));
    } else {
        for (idx, v) in report.violations.iter().enumerate() {
            if y_pos.0 < 35.0 {
                // New Page if near page bottom
                let (page_next, layer_next) = doc.add_page(Mm(210.0), Mm(297.0), "Layer 1");
                current_layer = doc.get_page(page_next).get_layer(layer_next);
                y_pos = Mm(280.0);
            }

            let (sev_label, (r, g, b)) = match v.severity.as_str() {
                "critical" => ("[CRITICAL]", (0.8, 0.1, 0.1)),
                "warning"  => ("[WARNING]", (0.9, 0.6, 0.1)),
                _          => ("[INFO]", (0.2, 0.5, 0.8)),
            };

            current_layer.set_fill_color(Color::Rgb(Rgb::new(r, g, b, None)));
            current_layer.use_text(format!("{} {}. {}", sev_label, idx + 1, v.title), 10.0, Mm(15.0), y_pos, &font_bold);
            current_layer.set_fill_color(Color::Rgb(Rgb::new(0.0, 0.0, 0.0, None)));
            y_pos -= Mm(5.0);

            current_layer.use_text(format!("Rule: {}  |  Domain: {}", v.rule, v.domain), 8.5, Mm(15.0), y_pos, &font_bold);
            y_pos -= Mm(4.5);

            let desc_line = sanitize_pdf_string(&v.description);
            current_layer.use_text(format!("Description: {}", truncate_line(&desc_line, 90)), 8.0, Mm(15.0), y_pos, &font_regular);
            y_pos -= Mm(4.0);

            let rec_line = sanitize_pdf_string(&v.recommendation);
            current_layer.use_text(format!("Action Required: {}", truncate_line(&rec_line, 90)), 8.0, Mm(15.0), y_pos, &font_regular);
            y_pos -= Mm(4.0);

            if let (Some(start), Some(end)) = (v.start_char, v.end_char) {
                current_layer.use_text(format!("Offset Range: Chars {}-{}", start, end), 8.0, Mm(15.0), y_pos, &font_regular);
                y_pos -= Mm(4.0);
            }

            if let Some(ref snippet) = v.snippet {
                let clean_snip = sanitize_pdf_string(snippet);
                current_layer.use_text(format!("Matched Text: \"{}\"", truncate_line(&clean_snip, 85)), 8.0, Mm(15.0), y_pos, &font_regular);
                y_pos -= Mm(4.0);
            }

            if let Some(ref citation) = v.article_citation {
                let clean_cit = sanitize_pdf_string(citation);
                current_layer.set_fill_color(Color::Rgb(Rgb::new(0.1, 0.3, 0.6, None)));
                current_layer.use_text(format!("Statutory Citation: {}", truncate_line(&clean_cit, 85)), 8.0, Mm(15.0), y_pos, &font_bold);
                current_layer.set_fill_color(Color::Rgb(Rgb::new(0.0, 0.0, 0.0, None)));
                y_pos -= Mm(4.0);
            }

            if let Some(ref statutory) = v.statutory_text {
                let clean_stat = sanitize_pdf_string(statutory);
                current_layer.use_text(format!("Statutory Provision: \"{}\"", truncate_line(&clean_stat, 85)), 8.0, Mm(15.0), y_pos, &font_regular);
                y_pos -= Mm(4.0);
            }

            y_pos -= Mm(4.0); // Margin between items
        }
    }

    // -------------------------------------------------------------------------
    // Footer Banner
    // -------------------------------------------------------------------------
    current_layer.use_text("Generated by Kagua Intelligence Engine — Confidential Regulatory Compliance Record", 7.5, Mm(15.0), Mm(10.0), &font_regular);

    // Write PDF bytes
    let mut pdf_bytes = Vec::new();
    {
        let mut writer = BufWriter::new(&mut pdf_bytes);
        doc.save(&mut writer).map_err(|e| e.to_string())?;
    }

    Ok(pdf_bytes)
}

fn sanitize_pdf_string(s: &str) -> String {
    s.replace('\n', " ").replace('\r', "").replace('\t', " ")
}

fn truncate_line(s: &str, max_chars: usize) -> String {
    if s.len() > max_chars {
        format!("{}...", &s[..max_chars])
    } else {
        s.to_string()
    }
}
