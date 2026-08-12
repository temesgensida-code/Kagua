<script lang="ts">
  import type { MappedViolation } from '$lib/services/api';

  interface Props {
    filename: string;
    rawText: string;
    violations: MappedViolation[];
    activeViolationIndex: number | null;
    onSelectViolation: (index: number) => void;
  }

  let { filename, rawText, violations, activeViolationIndex, onSelectViolation }: Props = $props();

  let viewerContainer: HTMLDivElement;

  type Segment =
    | { type: 'normal'; text: string }
    | {
        type: 'violation';
        text: string;
        violation: MappedViolation & { originalIdx: number };
        index: number;
      };

  // Compute text segments with highlighted spans
  let textSegments = $derived.by<Segment[]>(() => {
    if (!rawText) return [{ type: 'normal', text: 'No text content available' }];

    // Sort violations with valid character offsets
    const validViolations = violations
      .map((v, originalIdx) => ({ ...v, originalIdx }))
      .filter((v): v is typeof v & { start_char: number; end_char: number } => 
        typeof v.start_char === 'number' && typeof v.end_char === 'number' && v.end_char > v.start_char
      )
      .sort((a, b) => a.start_char - b.start_char);

    if (validViolations.length === 0) {
      return [{ type: 'normal', text: rawText }];
    }

    const segments: Segment[] = [];
    let cursor = 0;

    for (const v of validViolations) {
      const start = Math.max(cursor, Math.min(v.start_char, rawText.length));
      const end = Math.max(start, Math.min(v.end_char, rawText.length));

      if (start > cursor) {
        segments.push({
          type: 'normal',
          text: rawText.slice(cursor, start)
        });
      }

      if (end > start) {
        segments.push({
          type: 'violation',
          text: rawText.slice(start, end),
          violation: v,
          index: v.originalIdx
        });
        cursor = end;
      }
    }

    if (cursor < rawText.length) {
      segments.push({
        type: 'normal',
        text: rawText.slice(cursor)
      });
    }

    return segments;
  });

  let pulseIndex = $state<number | null>(null);
  let pulseTimer: any = null;

  $effect(() => {
    if (activeViolationIndex !== null && viewerContainer) {
      const targetEl = viewerContainer.querySelector(`[data-violation-idx="${activeViolationIndex}"]`);
      if (targetEl) {
        targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }

      // Trigger temporary 2.5s pulse highlight
      pulseIndex = activeViolationIndex;
      if (pulseTimer) clearTimeout(pulseTimer);
      pulseTimer = setTimeout(() => {
        pulseIndex = null;
      }, 2500);
    }
  });
</script>

<div class="doc-viewer-panel">
  <!-- Document Viewer Header -->
  <div class="viewer-header">
    <div class="title-box">
      <span class="view-icon">📄</span>
      <h3 class="doc-filename">{filename}</h3>
      <span class="char-length">{rawText ? rawText.length : 0} CHARS</span>
    </div>
    <div class="legend-box">
      <span class="legend-item legend-critical">
        <span class="dot"></span> CRITICAL ({violations.filter(v => v.severity === 'critical').length})
      </span>
      <span class="legend-item legend-warning">
        <span class="dot"></span> WARNING ({violations.filter(v => v.severity === 'warning').length})
      </span>
    </div>
  </div>

  <!-- Document Text Surface -->
  <div class="viewer-content" bind:this={viewerContainer}>
    <pre class="raw-text-surface">
      {#each textSegments as seg}
        {#if seg.type === 'normal'}
          <span>{seg.text}</span>
        {:else}
          <mark
            class="violation-mark severity-{seg.violation.severity}"
            class:active={activeViolationIndex === seg.index}
            class:pulse-highlight={pulseIndex === seg.index}
            data-violation-idx={seg.index}
            onclick={() => onSelectViolation(seg.index)}
            onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && onSelectViolation(seg.index)}
            role="button"
            tabindex="0"
            title="{seg.violation.rule}: {seg.violation.title}"
          >
            <span class="mark-label">[{seg.violation.severity.toUpperCase()}: {seg.violation.rule}]</span>
            {seg.text}
          </mark>
        {/if}
      {/each}
    </pre>
  </div>
</div>

<style>
  .doc-viewer-panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 520px;
    background: #080f17;
    border: 1px solid rgba(0, 240, 255, 0.18);
    border-radius: 6px;
    overflow: hidden;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.6);
  }

  .viewer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.85rem 1.25rem;
    background: rgba(13, 23, 36, 0.95);
    border-bottom: 1px solid rgba(0, 240, 255, 0.15);
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  .title-box {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .view-icon {
    font-size: 1rem;
  }

  .doc-filename {
    font-family: var(--font-title);
    font-size: 0.9rem;
    font-weight: 700;
    color: #ffffff;
    letter-spacing: 0.5px;
  }

  .char-length {
    font-family: var(--font-mono);
    font-size: 0.65rem;
    color: var(--text-muted);
    background: rgba(255, 255, 255, 0.05);
    padding: 2px 6px;
    border-radius: 3px;
  }

  .legend-box {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .legend-item {
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .legend-critical {
    color: #ff2a70;
  }

  .legend-warning {
    color: #ffd700;
  }

  .dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    display: inline-block;
  }

  .legend-critical .dot {
    background: #ff2a70;
    box-shadow: 0 0 6px #ff2a70;
  }

  .legend-warning .dot {
    background: #ffd700;
    box-shadow: 0 0 6px #ffd700;
  }

  .viewer-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
    background: #060b12;
  }

  .raw-text-surface {
    font-family: 'JetBrains Mono', 'Fira Code', var(--font-mono), monospace;
    font-size: 0.82rem;
    line-height: 1.65;
    color: #d1dbe5;
    white-space: pre-wrap;
    word-break: break-word;
    margin: 0;
  }

  .violation-mark {
    position: relative;
    padding: 2px 6px;
    border-radius: 3px;
    cursor: pointer;
    transition: all 0.2s ease;
    display: inline;
  }

  .violation-mark.severity-critical {
    background: rgba(255, 42, 112, 0.18);
    color: #ffa1be;
    border: 1px solid rgba(255, 42, 112, 0.6);
  }

  .violation-mark.severity-warning {
    background: rgba(255, 215, 0, 0.18);
    color: #fff1a1;
    border: 1px solid rgba(255, 215, 0, 0.6);
  }

  .violation-mark:hover {
    filter: brightness(1.25);
    box-shadow: 0 0 10px rgba(0, 240, 255, 0.4);
  }

  .violation-mark.active {
    outline: 2px solid var(--cyan-primary);
    box-shadow: 0 0 16px var(--cyan-primary);
    background: rgba(0, 240, 255, 0.25);
    color: #ffffff;
  }

  .violation-mark.pulse-highlight {
    animation: pulseGlow 0.8s ease-in-out infinite alternate;
    outline: 3px solid var(--cyan-primary);
    box-shadow: 0 0 25px var(--cyan-primary), 0 0 45px rgba(0, 240, 255, 0.7);
    z-index: 10;
  }

  @keyframes pulseGlow {
    0% {
      transform: scale(1);
      box-shadow: 0 0 10px var(--cyan-primary);
    }
    100% {
      transform: scale(1.04);
      box-shadow: 0 0 30px var(--cyan-primary), 0 0 50px rgba(0, 240, 255, 0.8);
    }
  }

  .mark-label {
    font-size: 0.6rem;
    font-weight: 800;
    font-family: var(--font-mono);
    text-transform: uppercase;
    margin-right: 4px;
    padding: 1px 4px;
    border-radius: 2px;
    background: rgba(0, 0, 0, 0.4);
    opacity: 0.85;
  }
</style>
