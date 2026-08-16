<script lang="ts">
  import DocumentViewer from "./DocumentViewer.svelte";
  import {
    downloadPdfAuditReport,
    type AnalysisReport,
    type MappedViolation,
  } from "$lib/services/api";
  import type { Framework } from "$lib/data/sampleDocs";
  import { soundState } from "$lib/services/sound.svelte";
  import {
    Download,
    FileCode,
    Lock,
    FileText,
    MapPin,
    Search,
  } from "@lucide/svelte";

  interface Props {
    file: {
      name: string;
      size: string;
      type: string;
      content?: string;
      blob?: Blob | File;
    };
    report?: AnalysisReport;
    frameworks: Framework[];
    onReset: () => void;
  }

  let { file, report, frameworks, onReset }: Props = $props();

  let activeViolationIndex = $state<number | null>(null);

  // Raw text extracted or passed from file sample
  let rawText = $derived(report?.raw_text || file.content || "");

  let activeFrameworks = $derived(frameworks.filter((f) => f.active));

  // Compute compliance score based on critical (-25) and warning (-10) violations
  let score = $derived.by(() => {
    if (!report) return 100;
    const penalty = report.critical_count * 25 + report.warning_count * 10;
    return Math.max(0, 100 - penalty);
  });

  let scoreColor = $derived(
    score >= 80 ? "#00ff88" : score >= 50 ? "#ffd700" : "#ff2a70",
  );

  let violations = $derived<MappedViolation[]>(report?.violations || []);

  let isDownloadingPdf = $state(false);

  async function handleDownloadPdf() {
    soundState.playClick();
    if (!report) {
      alert("No active backend audit report available to generate PDF.");
      return;
    }

    try {
      isDownloadingPdf = true;
      await downloadPdfAuditReport({
        ...report,
        raw_text: rawText,
      });
    } catch (err: any) {
      alert(`PDF export error: ${err.message}`);
    } finally {
      isDownloadingPdf = false;
    }
  }

  function handleDownloadJson() {
    soundState.playClick();
    const dataStr = JSON.stringify(
      report || { filename: file.name, violations, score },
      null,
      2,
    );
    const blob = new Blob([dataStr], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `kagua_audit_${file.name.replace(/[^a-z0-9]/gi, "_")}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  function selectViolation(idx: number) {
    activeViolationIndex = activeViolationIndex === idx ? null : idx;
  }

  function getFactDetails(item: any): {
    value: any;
    articleRef?: string;
    sourceText?: string;
  } {
    if (item && typeof item === "object" && item !== null) {
      return {
        value: item.value ?? item,
        articleRef: item.article_reference,
        sourceText: item.source_text,
      };
    }
    return { value: item };
  }
</script>

<div class="result-container">
  <!-- Top Bar Header -->
  <div class="result-header">
    <div class="file-info">
      <div class="file-icon-badge">{file.type}</div>
      <div class="file-details">
        <h3 class="file-title">{file.name}</h3>
        <span class="file-meta">
          {file.size} &bull;
          {#if report?.detected_jurisdiction}
            Jurisdiction: <strong class="badge-accent"
              >{report.detected_jurisdiction}</strong
            > &bull;
          {/if}
          {#if report?.suggested_domain}
            Auto-Selected Domain: <strong class="badge-accent"
              >{report.suggested_domain.toUpperCase()}</strong
            >
          {/if}
        </span>
      </div>
    </div>

    <div class="action-buttons">
      <button
        type="button"
        class="btn-rescan"
        onclick={() => {
          soundState.playClick();
          onReset();
        }}
      >
        &larr; SCAN ANOTHER DOCUMENT
      </button>
    </div>
  </div>

  <!-- Main Split Screen Work Area -->
  <div class="split-screen-grid">
    <!-- Left Panel: Split Document Viewer with Offset Highlights -->
    <div class="viewer-column">
      <DocumentViewer
        filename={file.name}
        fileBlob={file.blob}
        {rawText}
        {violations}
        {activeViolationIndex}
        onSelectViolation={selectViolation}
      />
    </div>

    <!-- Right Panel: Compliance Summary & Violations Cards -->
    <div class="summary-column">
      <!-- Standalone Severity Count Chips Outside Card -->
      <div class="summary-counts-column">
        <span class="count-chip critical">
          CRITICAL: {report
            ? report.critical_count
            : violations.filter((v) => v.severity === "critical").length}
        </span>
        <span class="count-chip warning">
          WARNING: {report
            ? report.warning_count
            : violations.filter((v) => v.severity === "warning").length}
        </span>
      </div>

      <!-- Privacy-Preserving RAG Status Card -->
      <!-- <div class="rag-privacy-card">
        <div class="rag-title-row">
          <span class="rag-icon"><Lock size={14} /></span>
          <h4 class="rag-title">PRIVACY-PRESERVING RAG ENGINE</h4>
          <span class="rag-live-badge">ACTIVE</span>
        </div>
        <div class="rag-stats-grid">
          <div class="rag-stat-item">
            <span class="rag-stat-num">{report?.pii_redacted_count ?? 6}</span>
            <span class="rag-stat-lbl">PII REDACTIONS (RAM ONLY)</span>
          </div>
          <div class="rag-stat-item">
            <span class="rag-stat-num">0</span>
            <span class="rag-stat-lbl">DISK PERSISTENCE (BYTES)</span>
          </div>
          <div class="rag-stat-item">
            <span class="rag-stat-num">100%</span>
            <span class="rag-stat-lbl">IN-MEMORY VECTOR RETRIEVAL</span>
          </div>
        </div>
      </div> -->

      <!-- Action Export Panel -->
      <div class="export-card">
        <h4 class="export-title">AUDIT REPORT EXPORT</h4>
        <div class="export-buttons">
          <button
            type="button"
            class="btn-pdf-export"
            disabled={isDownloadingPdf}
            onclick={handleDownloadPdf}
          >
            {#if isDownloadingPdf}
              GENERATING PDF...
            {:else}
              <Download size={14} /> DOWNLOAD PDF REPORT
            {/if}
          </button>
          <button
            type="button"
            class="btn-json-export"
            onclick={handleDownloadJson}
          >
            <FileCode size={14} /> EXPORT JSON
          </button>
        </div>
      </div>

      <!-- Violation Findings Cards List -->
      <div class="findings-card">
        <div class="findings-header">
          <h4 class="findings-title">
            REASONER FINDINGS ({violations.length})
          </h4>
          <span class="sub-info">Click card to jump to text offset</span>
        </div>

        <div class="findings-list">
          {#each violations as violation, idx}
            <div
              class="finding-item severity-{violation.severity}"
              class:selected={activeViolationIndex === idx}
              onclick={() => selectViolation(idx)}
              onkeydown={(e) =>
                (e.key === "Enter" || e.key === " ") && selectViolation(idx)}
              role="button"
              tabindex="0"
            >
              <div class="finding-top">
                <span class="badge-severity severity-{violation.severity}">
                  {violation.severity.toUpperCase()}
                </span>
                <span class="finding-domain">[{violation.domain}]</span>
                <span class="finding-rule-title">{violation.title}</span>
              </div>

              <div class="finding-rule-code">Rule: {violation.rule}</div>
              <p class="finding-desc">{violation.description}</p>

              {#if violation.recommendation}
                <div class="finding-rec">
                  <span class="rec-label">REMEDIATION:</span>
                  {violation.recommendation}
                </div>
              {/if}

              {#if violation.article_citation}
                <div class="statutory-citation-badge">
                  <FileText size={13} />
                  <strong>{violation.article_citation}</strong>
                </div>
              {/if}

              {#if violation.statutory_text}
                <div class="statutory-text-box">
                  <span class="stat-lbl">STATUTORY PROVISION:</span>
                  "{violation.statutory_text}"
                </div>
              {/if}

              <div class="card-action-row">
                <button
                  type="button"
                  class="jump-doc-btn"
                  class:active={activeViolationIndex === idx}
                  onclick={(e) => {
                    e.stopPropagation();
                    selectViolation(idx);
                  }}
                >
                  <MapPin size={13} />
                  {activeViolationIndex === idx
                    ? "Highlighting in Document..."
                    : "Jump to Issue in Document"}
                </button>

                {#if typeof violation.start_char === "number" && typeof violation.end_char === "number"}
                  <div class="offset-badge">
                    Chars {violation.start_char} &ndash; {violation.end_char}
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>

      <!-- Fact Provenance & Statutory Linkage Panel -->
      {#if report?.fact_provenance && Object.keys(report.fact_provenance).length > 0}
        <div class="provenance-card">
          <div class="provenance-header">
            <span class="prov-icon"><Search size={14} /></span>
            <h4 class="prov-title">FACT PROVENANCE & STATUTORY LINKAGE</h4>
          </div>
          <div class="provenance-list">
            {#each Object.entries(report.fact_provenance) as [factKey, factData]}
              {@const details = getFactDetails(factData)}
              <div class="prov-item">
                <div class="prov-top">
                  <span class="prov-key"
                    >{factKey}:
                    <strong class="prov-val"
                      >{JSON.stringify(details.value)}</strong
                    ></span
                  >
                  {#if details.articleRef}
                    <span class="prov-art-tag">{details.articleRef}</span>
                  {/if}
                </div>
                {#if details.sourceText}
                  <div class="prov-source">
                    <span class="prov-src-lbl">Contract Source:</span>
                    "{details.sourceText}"
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .result-container {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    animation: fadeIn 0.4s ease;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .result-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(13, 23, 36, 0.9);
    border: 1px solid rgba(0, 240, 255, 0.2);
    border-radius: 6px;
    padding: 0.85rem 1.25rem;
    flex-wrap: wrap;
    gap: 1rem;
  }

  .file-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .file-icon-badge {
    padding: 6px 10px;
    background: rgba(0, 240, 255, 0.15);
    border: 1px solid var(--cyan-primary);
    border-radius: 4px;
    color: var(--cyan-primary);
    font-family: var(--font-mono);
    font-size: 0.75rem;
    font-weight: 700;
  }

  .file-title {
    font-family: var(--font-title);
    font-size: 1.05rem;
    color: #ffffff;
    font-weight: 700;
  }

  .file-meta {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    color: var(--text-muted);
  }

  .badge-accent {
    color: var(--cyan-primary);
  }

  .btn-rescan {
    background: #132e35;
    border: 1px solid #1e434c;
    color: #e2f1f8;
    font-family: var(--font-title);
    font-size: 0.82rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    padding: 10px 20px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .btn-rescan:hover {
    background: #1c3f48;
    border-color: #2a5863;
    transform: translateY(-2px) scale(1.02);
  }

  /* Split Screen Layout */
  .split-screen-grid {
    display: grid;
    grid-template-columns: 1fr 400px;
    gap: 1.5rem;
    height: calc(100vh - 170px);
    min-height: 650px;
    max-height: 880px;
  }

  @media (max-width: 1024px) {
    .split-screen-grid {
      grid-template-columns: 1fr;
      height: auto;
      max-height: none;
    }
  }

  .viewer-column {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .summary-column {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    height: 100%;
    overflow-y: auto;
    padding-right: 4px;
  }

  /* Standalone Severity Count Chips Outside Card (Plain Text) */
  .summary-counts-column {
    display: flex;
    align-items: center;
    gap: 16px;
    flex-wrap: wrap;
    padding: 2px 0;
  }

  .count-chip {
    font-family: var(--font-mono);
    font-size: 0.82rem;
    font-weight: 800;
    letter-spacing: 1.5px;
    background: none;
    border: none;
    padding: 0;
    display: inline-flex;
    align-items: center;
  }

  .count-chip.critical {
    color: #ff2a70;
  }

  .count-chip.warning {
    color: #ffd700;
  }

  /* Privacy RAG Card */
  /* .rag-privacy-card {
    background: rgba(4, 12, 22, 0.85);
    border: 1px solid rgba(0, 240, 255, 0.25);
    border-radius: 6px;
    padding: 0.85rem 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    box-shadow: inset 0 0 15px rgba(0, 240, 255, 0.04);
  } */

  .rag-title-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .rag-icon {
    font-size: 0.9rem;
  }

  .rag-title {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    color: #ffffff;
    flex: 1;
  }

  .rag-live-badge {
    font-family: var(--font-mono);
    font-size: 0.58rem;
    font-weight: 800;
    color: #00ff88;
    background: rgba(0, 255, 136, 0.12);
    border: 1px solid rgba(0, 255, 136, 0.4);
    padding: 2px 6px;
    border-radius: 3px;
  }

  .rag-stats-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 6px;
  }

  .rag-stat-item {
    background: rgba(0, 240, 255, 0.04);
    border: 1px solid rgba(0, 240, 255, 0.12);
    border-radius: 4px;
    padding: 6px;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }

  .rag-stat-num {
    font-family: var(--font-mono);
    font-size: 0.95rem;
    font-weight: 800;
    color: var(--cyan-primary);
  }

  .rag-stat-lbl {
    font-family: var(--font-mono);
    font-size: 0.52rem;
    color: var(--text-muted);
    line-height: 1.1;
    margin-top: 2px;
  }

  /* Export Card */
  .export-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .export-title {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    letter-spacing: 1.5px;
    color: var(--cyan-muted);
    font-weight: 700;
  }

  .export-buttons {
    display: flex;
    gap: 10px;
  }

  .btn-pdf-export {
    flex: 1;
    font-family: var(--font-title);
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    color: #e2f1f8;
    background: #132e35;
    border: 1px solid #1e434c;
    border-radius: 4px;
    padding: 10px 14px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .btn-pdf-export:hover:not(:disabled) {
    background: #1c3f48;
    border-color: #2a5863;
    transform: translateY(-2px) scale(1.02);
  }

  .btn-pdf-export:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-json-export {
    font-family: var(--font-title);
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    color: #e2f1f8;
    background: #132e35;
    border: 1px solid #1e434c;
    padding: 10px 14px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .btn-json-export:hover {
    background: #1c3f48;
    border-color: #2a5863;
    transform: translateY(-2px) scale(1.02);
  }

  /* Findings List */
  .findings-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.15);
    border-radius: 6px;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
    flex: 1;
  }

  .findings-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 0.5rem;
  }

  .findings-title {
    font-family: var(--font-mono);
    font-size: 0.72rem;
    letter-spacing: 1.5px;
    color: #ffffff;
    font-weight: 700;
  }

  .sub-info {
    font-family: var(--font-mono);
    font-size: 0.62rem;
    color: var(--text-muted);
  }

  .findings-list {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    max-height: 520px;
    overflow-y: auto;
  }

  .finding-item {
    background: rgba(6, 11, 18, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 4px;
    padding: 0.85rem;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .finding-item:hover {
    border-color: rgba(0, 240, 255, 0.4);
    background: rgba(0, 240, 255, 0.04);
  }

  .finding-item.selected {
    border-color: var(--cyan-primary);
    box-shadow: 0 0 14px rgba(0, 240, 255, 0.25);
    background: rgba(0, 240, 255, 0.08);
  }

  .finding-top {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .badge-severity {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 2px;
  }

  .badge-severity.severity-critical {
    background: #614041;
    color: #e2f1f8;
    border: 1px solid #7d4d4e;
  }

  .badge-severity.severity-warning {
    background: #614016;
    color: #e2f1f8;
    border: 1px solid #7d531d;
  }

  .finding-domain {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    color: var(--cyan-muted);
    font-weight: 700;
  }

  .finding-rule-title {
    font-family: var(--font-title);
    font-size: 0.82rem;
    color: #ffffff;
    font-weight: 600;
  }

  .finding-rule-code {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    color: #8fa0b5;
  }

  .finding-desc {
    font-family: var(--font-body);
    font-size: 0.78rem;
    color: var(--text-muted);
    line-height: 1.35;
  }

  .finding-rec {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    color: #a0b2c6;
    background: rgba(0, 240, 255, 0.04);
    border-left: 2px solid var(--cyan-primary);
    padding: 4px 8px;
    border-radius: 2px;
  }

  .rec-label {
    color: var(--cyan-primary);
    font-weight: 700;
  }

  .offset-badge {
    font-family: var(--font-mono);
    font-size: 0.62rem;
    color: var(--cyan-primary);
    background: rgba(0, 240, 255, 0.06);
    padding: 2px 6px;
    border-radius: 2px;
    align-self: flex-start;
  }

  .statutory-citation-badge {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    color: #5ce1e6;
    background: rgba(0, 240, 255, 0.08);
    border: 1px solid rgba(0, 240, 255, 0.25);
    padding: 4px 8px;
    border-radius: 3px;
  }

  .statutory-text-box {
    font-family: var(--font-body);
    font-size: 0.72rem;
    color: #9cb3c9;
    background: rgba(4, 12, 22, 0.9);
    border-left: 2px solid #5ce1e6;
    padding: 5px 8px;
    border-radius: 2px;
    font-style: italic;
  }

  .stat-lbl {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    font-weight: 700;
    color: #5ce1e6;
    font-style: normal;
  }

  /* Fact Provenance Card */
  .provenance-card {
    background: #0d1724;
    border: 1px solid rgba(0, 240, 255, 0.2);
    border-radius: 6px;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .provenance-header {
    display: flex;
    align-items: center;
    gap: 8px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    padding-bottom: 0.4rem;
  }

  .prov-icon {
    font-size: 0.9rem;
  }

  .prov-title {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    letter-spacing: 1.5px;
    color: #ffffff;
    font-weight: 700;
  }

  .provenance-list {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }

  .prov-item {
    background: rgba(6, 11, 18, 0.85);
    border: 1px solid rgba(0, 240, 255, 0.1);
    border-radius: 4px;
    padding: 0.6rem;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .prov-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .prov-key {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    color: #a0b2c6;
  }

  .prov-val {
    color: var(--cyan-primary);
  }

  .prov-art-tag {
    font-family: var(--font-mono);
    font-size: 0.6rem;
    font-weight: 700;
    color: #ffd700;
    background: rgba(255, 215, 0, 0.12);
    border: 1px solid rgba(255, 215, 0, 0.3);
    padding: 1px 5px;
    border-radius: 2px;
  }

  .prov-source {
    font-family: var(--font-body);
    font-size: 0.7rem;
    color: #7b90a6;
    font-style: italic;
  }

  .prov-src-lbl {
    font-family: var(--font-mono);
    font-size: 0.58rem;
    color: var(--cyan-muted);
    font-style: normal;
  }

  .card-action-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-top: 0.25rem;
    flex-wrap: wrap;
  }

  .jump-doc-btn {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 700;
    color: #e2f1f8;
    background: #132e35;
    border: 1px solid #1e434c;
    padding: 6px 14px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  .jump-doc-btn:hover {
    background: #1c3f48;
    border-color: #2a5863;
    transform: translateY(-1px);
  }

  .jump-doc-btn.active {
    background: #1e434c;
    color: #ffffff;
    border-color: #2a5863;
  }

  /* ─── Light Mode Overrides ─── */
  :global([data-theme="light"]) .result-container {
    color: #2d3a45;
  }

  :global([data-theme="light"]) .result-header {
    background: #c2c6ca;
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .file-icon-badge {
    background: #69818d;
    color: #ffffff;
  }

  :global([data-theme="light"]) .file-title {
    color: #2d3a45;
  }

  :global([data-theme="light"]) .file-meta {
    color: #5a6a78;
  }

  :global([data-theme="light"]) .badge-accent {
    color: #69818d;
  }

  :global([data-theme="light"]) .btn-rescan {
    background: #69818d;
    border-color: #8a9aa8;
    color: #ffffff;
  }

  :global([data-theme="light"]) .btn-rescan:hover {
    background: #5a7380;
    border-color: #69818d;
  }

  :global([data-theme="light"]) .count-chip.critical {
    color: #cc2244;
  }

  :global([data-theme="light"]) .count-chip.warning {
    color: #b8960e;
  }

  :global([data-theme="light"]) .export-card {
    background: #c2c6ca;
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .export-title {
    color: #5a6a78;
  }

  :global([data-theme="light"]) .btn-pdf-export,
  :global([data-theme="light"]) .btn-json-export {
    background: #69818d;
    border-color: #8a9aa8;
    color: #ffffff;
  }

  :global([data-theme="light"]) .btn-pdf-export:hover:not(:disabled),
  :global([data-theme="light"]) .btn-json-export:hover {
    background: #5a7380;
    border-color: #69818d;
  }

  :global([data-theme="light"]) .findings-card {
    background: #c2c6ca;
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .findings-header {
    border-bottom-color: rgba(0, 0, 0, 0.1);
  }

  :global([data-theme="light"]) .findings-title {
    color: #2d3a45;
  }

  :global([data-theme="light"]) .sub-info {
    color: #5a6a78;
  }

  :global([data-theme="light"]) .finding-item {
    background: rgba(175, 179, 183, 0.5);
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .finding-item:hover {
    border-color: #69818d;
    background: rgba(105, 129, 141, 0.1);
  }

  :global([data-theme="light"]) .finding-item.selected {
    border-color: #69818d;
    box-shadow: 0 0 10px rgba(105, 129, 141, 0.2);
    background: rgba(105, 129, 141, 0.15);
  }

  :global([data-theme="light"]) .badge-severity.severity-critical {
    background: #cc2244;
    color: #ffffff;
    border-color: #aa1d3a;
  }

  :global([data-theme="light"]) .badge-severity.severity-warning {
    background: #b8960e;
    color: #ffffff;
    border-color: #9a7d0b;
  }

  :global([data-theme="light"]) .finding-domain {
    color: #69818d;
  }

  :global([data-theme="light"]) .finding-rule-title {
    color: #2d3a45;
  }

  :global([data-theme="light"]) .finding-rule-code {
    color: #5a6a78;
  }

  :global([data-theme="light"]) .finding-desc {
    color: #5a6a78;
  }

  :global([data-theme="light"]) .finding-rec {
    background: rgba(105, 129, 141, 0.08);
    border-left-color: #69818d;
    color: #4a5a68;
  }

  :global([data-theme="light"]) .rec-label {
    color: #69818d;
  }

  :global([data-theme="light"]) .statutory-citation-badge {
    color: #69818d;
    background: rgba(105, 129, 141, 0.1);
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .statutory-text-box {
    background: rgba(194, 198, 202, 0.5);
    border-left-color: #69818d;
    color: #4a5a68;
  }

  :global([data-theme="light"]) .stat-lbl {
    color: #69818d;
  }

  :global([data-theme="light"]) .jump-doc-btn {
    background: #69818d;
    border-color: #8a9aa8;
    color: #ffffff;
  }

  :global([data-theme="light"]) .jump-doc-btn:hover {
    background: #5a7380;
    border-color: #69818d;
  }

  :global([data-theme="light"]) .jump-doc-btn.active {
    background: #4a6370;
    color: #ffffff;
    border-color: #5a7380;
  }

  :global([data-theme="light"]) .offset-badge {
    color: #69818d;
    background: rgba(105, 129, 141, 0.1);
  }

  :global([data-theme="light"]) .provenance-card {
    background: #c2c6ca;
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .provenance-header {
    border-bottom-color: rgba(0, 0, 0, 0.1);
  }

  :global([data-theme="light"]) .prov-title {
    color: #2d3a45;
  }

  :global([data-theme="light"]) .provenance-list {
    color: #4a5a68;
  }

  :global([data-theme="light"]) .prov-item {
    background: rgba(175, 179, 183, 0.5);
    border-color: #8a9aa8;
  }

  :global([data-theme="light"]) .prov-key {
    color: #2d3a45;
    font-weight: 600;
  }

  :global([data-theme="light"]) .prov-val {
    color: #1e434c;
    font-weight: 700;
  }

  :global([data-theme="light"]) .prov-art-tag {
    background: rgba(184, 150, 14, 0.18);
    border-color: #b8960e;
    color: #735b00;
  }

  :global([data-theme="light"]) .prov-source {
    color: #4a5a68;
  }

  :global([data-theme="light"]) .prov-src-lbl {
    color: #69818d;
    font-weight: 700;
  }

  /* 2px right+bottom shadow on all action buttons */
  .btn-rescan,
  .btn-pdf-export,
  .btn-json-export,
  .jump-doc-btn {
    box-shadow: 2px 2px 0 rgba(0, 0, 0, 0.25);
  }

  :global([data-theme="light"]) .btn-rescan,
  :global([data-theme="light"]) .btn-pdf-export,
  :global([data-theme="light"]) .btn-json-export,
  :global([data-theme="light"]) .jump-doc-btn {
    box-shadow: 2px 2px 0 rgba(0, 0, 0, 0.1);
  }
</style>
