<script lang="ts">
  import { onMount } from 'svelte';
  import type { MappedViolation } from '$lib/services/api';

  let pdfjsLib = $state<any>(null);

  onMount(async () => {
    if (typeof window !== 'undefined') {
      const pdfModule = await import('pdfjs-dist');
      pdfjsLib = pdfModule;
      pdfjsLib.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjsLib.version}/pdf.worker.min.mjs`;
    }
  });

  interface Props {
    filename: string;
    fileBlob?: Blob | File;
    rawText: string;
    violations: MappedViolation[];
    activeViolationIndex: number | null;
    onSelectViolation: (index: number) => void;
  }

  let { filename, fileBlob, rawText, violations, activeViolationIndex, onSelectViolation }: Props = $props();

  let viewerContainer = $state<HTMLDivElement | undefined>(undefined);
  let pdfCanvasContainer = $state<HTMLDivElement | undefined>(undefined);

  let isPdf = $derived(
    Boolean((fileBlob && fileBlob.type.includes('pdf')) || filename.toLowerCase().endsWith('.pdf'))
  );

  let numPages = $state(0);
  let currentPage = $state(1);
  let zoomLevel = $state(1.15);
  let pdfDoc = $state<any>(null);
  let isPdfLoading = $state(false);
  let pdfError = $state<string | null>(null);
  let pageTexts = $state<Record<number, string>>({});
  let viewMode = $state<'pdf' | 'text'>('pdf');
  let isExpanded = $state(false);

  let pulseIndex = $state<number | null>(null);
  let pulseTimer: any = null;
  let highlightedPage = $state<number | null>(null);

  onMount(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape' && isExpanded) {
        isExpanded = false;
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  });

  // Load PDF when fileBlob or isPdf changes
  $effect(() => {
    if (isPdf && fileBlob) {
      if (!pdfjsLib) {
        import('pdfjs-dist').then(mod => {
          pdfjsLib = mod;
          pdfjsLib.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjsLib.version}/pdf.worker.min.mjs`;
          loadPdf(fileBlob);
        });
      } else {
        loadPdf(fileBlob);
      }
    }
  });

  async function loadPdf(blob: Blob | File) {
    if (!pdfjsLib) return;
    try {
      isPdfLoading = true;
      pdfError = null;
      pageTexts = {};
      const arrayBuffer = await blob.arrayBuffer();
      const loadingTask = pdfjsLib.getDocument({ data: arrayBuffer });
      pdfDoc = await loadingTask.promise;
      numPages = pdfDoc.numPages;

      // Extract text content per page for violation snippet matching
      for (let pageNum = 1; pageNum <= numPages; pageNum++) {
        const page = await pdfDoc.getPage(pageNum);
        const textContent = await page.getTextContent();
        const textItems = textContent.items.map((item: any) => item.str).join(' ');
        pageTexts[pageNum] = textItems.toLowerCase();
      }

      await renderPdfPages();
    } catch (err: any) {
      console.error('PDF rendering error:', err);
      pdfError = `Could not render PDF canvas: ${err.message}`;
      viewMode = 'text';
    } finally {
      isPdfLoading = false;
    }
  }

  async function renderPdfPages() {
    if (!pdfDoc || !pdfCanvasContainer) return;
    pdfCanvasContainer.innerHTML = '';

    for (let pageNum = 1; pageNum <= numPages; pageNum++) {
      const page = await pdfDoc.getPage(pageNum);
      const viewport = page.getViewport({ scale: zoomLevel });

      const pageWrapper = document.createElement('div');
      pageWrapper.className = 'pdf-page-wrapper';
      pageWrapper.dataset.pageNum = String(pageNum);

      const canvas = document.createElement('canvas');
      canvas.className = 'pdf-canvas';
      const context = canvas.getContext('2d');
      canvas.height = viewport.height;
      canvas.width = viewport.width;

      const pageBadge = document.createElement('div');
      pageBadge.className = 'pdf-page-number-badge';
      pageBadge.innerText = `PAGE ${pageNum} OF ${numPages}`;

      pageWrapper.appendChild(canvas);
      pageWrapper.appendChild(pageBadge);
      pdfCanvasContainer.appendChild(pageWrapper);

      const renderContext = {
        canvasContext: context!,
        viewport: viewport
      };
      await page.render(renderContext).promise;
    }
  }

  // Handle active violation scroll and temporary highlight pulse
  $effect(() => {
    if (activeViolationIndex !== null && violations[activeViolationIndex]) {
      const v = violations[activeViolationIndex];

      // Trigger temporary 2.5s pulse highlight
      pulseIndex = activeViolationIndex;
      if (pulseTimer) clearTimeout(pulseTimer);
      pulseTimer = setTimeout(() => {
        pulseIndex = null;
        highlightedPage = null;
      }, 2500);

      if (isPdf && viewMode === 'pdf' && pdfDoc && pdfCanvasContainer) {
        // --- Improved Page Detection ---
        // Build a ranked list of candidate search terms from the violation
        const searchTerms: string[] = [];

        // 1. Try the snippet text first (most specific)
        if (v.snippet) {
          const snippetWords = v.snippet.toLowerCase().replace(/[^\w\s]/g, ' ').trim();
          if (snippetWords.length > 10) searchTerms.push(snippetWords.slice(0, 60));
          // Also try first 30 chars
          if (snippetWords.length > 6) searchTerms.push(snippetWords.slice(0, 30));
        }

        // 2. Try individual meaningful keywords from snippet
        if (v.snippet) {
          const words = v.snippet.toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .split(/\s+/)
            .filter(w => w.length > 5)
            .slice(0, 5);
          searchTerms.push(...words);
        }

        // 3. Try title keywords
        if (v.title) {
          const titleWords = v.title.toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .split(/\s+/)
            .filter(w => w.length > 4);
          searchTerms.push(...titleWords);
        }

        // 4. Try description keywords
        if (v.description) {
          const descWords = v.description.toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .split(/\s+/)
            .filter(w => w.length > 6)
            .slice(0, 5);
          searchTerms.push(...descWords);
        }

        // Score each page — the page with the most term matches wins
        let bestPage = 1;
        let bestScore = -1;

        for (let p = 1; p <= numPages; p++) {
          const pageText = pageTexts[p];
          if (!pageText) continue;

          let score = 0;
          for (const term of searchTerms) {
            if (pageText.includes(term)) {
              // More weight for longer/more specific terms
              score += term.length;
            }
          }
          if (score > bestScore) {
            bestScore = score;
            bestPage = p;
          }
        }

        highlightedPage = bestPage;
        currentPage = bestPage;

        // --- Scroll to detected page inside the viewer-content div ---
        // Use manual offsetTop-based scroll (not scrollIntoView which scrolls window)
        const targetPageEl = pdfCanvasContainer.querySelector(
          `[data-page-num="${bestPage}"]`
        ) as HTMLElement | null;

        if (targetPageEl && viewerContainer) {
          // offsetTop relative to pdfCanvasContainer, then add container's offsetTop
          const containerTop = pdfCanvasContainer.offsetTop;
          const pageRelativeTop = targetPageEl.offsetTop;
          const scrollTarget = containerTop + pageRelativeTop - 20; // 20px breathing room

          viewerContainer.scrollTo({
            top: scrollTarget,
            behavior: 'smooth'
          });

          // Apply pulse glow class temporarily
          targetPageEl.classList.add('pulse-page-highlight');
          setTimeout(() => {
            targetPageEl.classList.remove('pulse-page-highlight');
          }, 2500);
        }
      } else if (viewerContainer) {
        // Fallback text view scroll
        const targetEl = viewerContainer.querySelector(`[data-violation-idx="${activeViolationIndex}"]`);
        if (targetEl) {
          targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }
    }
  });

  function changeZoom(delta: number) {
    zoomLevel = Math.max(0.6, Math.min(2.5, zoomLevel + delta));
    if (pdfDoc) {
      renderPdfPages();
    }
  }

  type Segment =
    | { type: 'normal'; text: string }
    | {
        type: 'violation';
        text: string;
        violation: MappedViolation & { originalIdx: number };
        index: number;
      };

  // Compute text segments with highlighted spans for text mode fallback
  let textSegments = $derived.by<Segment[]>(() => {
    if (!rawText) return [{ type: 'normal', text: 'No text content available' }];

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
        segments.push({ type: 'normal', text: rawText.slice(cursor, start) });
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
      segments.push({ type: 'normal', text: rawText.slice(cursor) });
    }

    return segments;
  });
</script>

<div class="doc-viewer-panel" class:fullscreen={isExpanded}>
  <!-- Document Viewer Header -->
  <div class="viewer-header">
    <div class="title-box">
      <span class="view-icon">{isPdf ? '📕' : '📄'}</span>
      <h3 class="doc-filename">{filename}</h3>
      <span class="char-length">{isPdf ? `${numPages} PAGES` : `${rawText ? rawText.length : 0} CHARS`}</span>
    </div>

    <div class="header-actions">
      <!-- PDF Viewer Controls -->
      {#if isPdf && viewMode === 'pdf'}
        <div class="pdf-controls">
          <button type="button" class="ctrl-btn" onclick={() => changeZoom(-0.15)} title="Zoom Out">&minus;</button>
          <span class="zoom-val">{Math.round(zoomLevel * 100)}%</span>
          <button type="button" class="ctrl-btn" onclick={() => changeZoom(0.15)} title="Zoom In">&plus;</button>
        </div>
      {/if}

      <!-- Mode Toggle -->
      {#if isPdf}
        <div class="mode-toggle">
          <button
            type="button"
            class="toggle-btn"
            class:active={viewMode === 'pdf'}
            onclick={() => (viewMode = 'pdf')}
          >
            PDF VIEWER
          </button>
          <button
            type="button"
            class="toggle-btn"
            class:active={viewMode === 'text'}
            onclick={() => (viewMode = 'text')}
          >
            TEXT VIEW
          </button>
        </div>
      {/if}

      <!-- Expand / Fullscreen Button -->
      <button
        type="button"
        class="expand-btn"
        class:expanded={isExpanded}
        onclick={() => (isExpanded = !isExpanded)}
        title={isExpanded ? 'Exit Fullscreen View (Esc)' : 'Expand PDF Card to Fullscreen'}
      >
        {#if isExpanded}
          <span class="btn-icon">↙↗</span> EXIT
        {:else}
          <span class="btn-icon">⛶</span> EXPAND
        {/if}
      </button>
    </div>
  </div>

  <!-- PDF / Text Viewer Content Surface -->
  <div class="viewer-content" bind:this={viewerContainer}>
    {#if isPdf && viewMode === 'pdf'}
      {#if isPdfLoading}
        <div class="pdf-loader">
          <div class="spinner"></div>
          <span>Rendering PDF pages...</span>
        </div>
      {:else if pdfError}
        <div class="pdf-error-box">
          <span class="err-icon">⚠️</span>
          <span>{pdfError}</span>
        </div>
      {/if}

      <div class="pdf-canvas-container" bind:this={pdfCanvasContainer}></div>
    {:else}
      <!-- Plain Text Fallback Viewer -->
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
    {/if}
  </div>
</div>

<style>
  .doc-viewer-panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 580px;
    background: #080f17;
    border: 1px solid rgba(0, 240, 255, 0.18);
    border-radius: 6px;
    overflow: hidden;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.6);
    transition: all 0.35s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .doc-viewer-panel.fullscreen {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    z-index: 999999;
    border-radius: 0;
    border: none;
    box-shadow: 0 0 60px rgba(0, 240, 255, 0.35);
  }

  .viewer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem 1.25rem;
    background: rgba(13, 23, 36, 0.95);
    border-bottom: 1px solid rgba(0, 240, 255, 0.15);
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .expand-btn {
    display: flex;
    align-items: center;
    gap: 5px;
    font-family: var(--font-mono);
    font-size: 0.68rem;
    font-weight: 700;
    background: rgba(0, 240, 255, 0.08);
    border: 1px solid rgba(0, 240, 255, 0.3);
    color: var(--cyan-primary);
    padding: 4px 10px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .expand-btn:hover {
    background: rgba(0, 240, 255, 0.22);
    border-color: var(--cyan-primary);
    color: #ffffff;
    box-shadow: 0 0 12px rgba(0, 240, 255, 0.4);
  }

  .expand-btn.expanded {
    background: rgba(255, 42, 112, 0.2);
    border-color: rgba(255, 42, 112, 0.6);
    color: #ff9ec4;
  }

  .expand-btn.expanded:hover {
    background: rgba(255, 42, 112, 0.35);
    color: #ffffff;
    box-shadow: 0 0 12px rgba(255, 42, 112, 0.5);
  }

  .btn-icon {
    font-size: 0.85rem;
  }

  .title-box {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .view-icon {
    font-size: 1.1rem;
  }

  .doc-filename {
    font-family: var(--font-title);
    font-size: 0.9rem;
    font-weight: 700;
    color: #ffffff;
    letter-spacing: 0.5px;
    margin: 0;
  }

  .char-length {
    font-family: var(--font-mono);
    font-size: 0.65rem;
    color: var(--text-muted);
    background: rgba(255, 255, 255, 0.05);
    padding: 2px 6px;
    border-radius: 3px;
  }

  .pdf-controls {
    display: flex;
    align-items: center;
    gap: 6px;
    background: rgba(0, 0, 0, 0.4);
    padding: 2px 8px;
    border-radius: 4px;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .ctrl-btn {
    background: none;
    border: none;
    color: var(--cyan-primary);
    font-size: 1rem;
    font-weight: bold;
    cursor: pointer;
    padding: 0 4px;
  }

  .ctrl-btn:hover {
    color: #ffffff;
  }

  .zoom-val {
    font-family: var(--font-mono);
    font-size: 0.7rem;
    color: #d1dbe5;
  }

  .mode-toggle {
    display: flex;
    background: rgba(0, 0, 0, 0.4);
    padding: 2px;
    border-radius: 4px;
    border: 1px solid rgba(0, 240, 255, 0.2);
  }

  .toggle-btn {
    font-family: var(--font-mono);
    font-size: 0.65rem;
    font-weight: 700;
    background: none;
    border: none;
    color: var(--text-muted);
    padding: 4px 8px;
    border-radius: 3px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .toggle-btn.active {
    background: var(--cyan-primary);
    color: #050b14;
  }

  .viewer-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.25rem;
    background: #060b12;
    display: flex;
    flex-direction: column;
    align-items: center;
    scrollbar-width: thin;
    scrollbar-color: rgba(0, 240, 255, 0.4) rgba(6, 11, 18, 0.9);
  }

  .viewer-content::-webkit-scrollbar {
    width: 6px;
  }

  .viewer-content::-webkit-scrollbar-track {
    background: rgba(6, 11, 18, 0.9);
  }

  .viewer-content::-webkit-scrollbar-thumb {
    background: rgba(0, 240, 255, 0.4);
    border-radius: 3px;
  }

  .viewer-content::-webkit-scrollbar-thumb:hover {
    background: var(--cyan-primary);
  }

  .pdf-loader {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    padding: 3rem;
    color: var(--cyan-primary);
    font-family: var(--font-mono);
    font-size: 0.85rem;
  }

  .spinner {
    width: 28px;
    height: 28px;
    border: 3px solid rgba(0, 240, 255, 0.2);
    border-top-color: var(--cyan-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .pdf-error-box {
    color: #ff2a70;
    font-family: var(--font-mono);
    font-size: 0.8rem;
    padding: 1rem;
    text-align: center;
  }

  .pdf-canvas-container {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    width: 100%;
    align-items: center;
  }

  :global(.pdf-page-wrapper) {
    position: relative;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.8);
    border-radius: 4px;
    overflow: hidden;
    transition: transform 0.3s ease, box-shadow 0.3s ease, outline 0.3s ease;
    background: #ffffff;
  }

  :global(.pdf-canvas) {
    display: block;
    max-width: 100%;
    height: auto;
  }

  :global(.pdf-page-number-badge) {
    position: absolute;
    bottom: 8px;
    right: 12px;
    background: rgba(0, 0, 0, 0.7);
    color: #ffffff;
    font-family: monospace;
    font-size: 0.65rem;
    padding: 2px 8px;
    border-radius: 3px;
    pointer-events: none;
  }

  :global(.pdf-page-wrapper.pulse-page-highlight) {
    outline: 4px solid var(--cyan-primary) !important;
    box-shadow: 0 0 35px var(--cyan-primary), 0 0 60px rgba(0, 240, 255, 0.7) !important;
    animation: pdfPageGlow 0.8s ease-in-out infinite alternate !important;
  }

  @keyframes pdfPageGlow {
    0% {
      transform: scale(1);
    }
    100% {
      transform: scale(1.02);
    }
  }

  .raw-text-surface {
    font-family: 'JetBrains Mono', 'Fira Code', var(--font-mono), monospace;
    font-size: 0.82rem;
    line-height: 1.65;
    color: #d1dbe5;
    white-space: pre-wrap;
    word-break: break-word;
    margin: 0;
    width: 100%;
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
