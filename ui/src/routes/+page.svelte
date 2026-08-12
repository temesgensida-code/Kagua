<script lang="ts">
  import HeaderSection from '$lib/components/HeaderSection.svelte';
  import DropZone from '$lib/components/DropZone.svelte';
  import AnalysisResultView from '$lib/components/AnalysisResultView.svelte';
  import { INITIAL_FRAMEWORKS, type Framework } from '$lib/data/sampleDocs';
  import { analyzeDocument, subscribeProgress, type AnalysisReport, type ProgressEvent } from '$lib/services/api';

  let frameworks = $state<Framework[]>(INITIAL_FRAMEWORKS);
  let isScanning = $state(false);
  let currentStageMessage = $state('');
  let progressEvents = $state<ProgressEvent[]>([]);
  let report = $state<AnalysisReport | undefined>(undefined);
  let selectedFile = $state<{ name: string; size: string; type: string; content?: string } | null>(null);

  function toggleFramework(id: string) {
    frameworks = frameworks.map(fw =>
      fw.id === id ? { ...fw, active: !fw.active } : fw
    );
  }

  async function handleFileSelected(fileData: Blob | File, filename: string, sampleContent?: string) {
    const sizeMB = (fileData.size / (1024 * 1024)).toFixed(2) + ' MB';
    const ext = filename.split('.').pop()?.toUpperCase() || 'DOC';

    // Clear any previous analysis report state
    report = undefined;

    selectedFile = {
      name: filename,
      size: sizeMB,
      type: ext,
      content: sampleContent
    };

    isScanning = true;
    progressEvents = [];
    currentStageMessage = 'CONNECTING TO RUST CORE BACKEND...';

    // Subscribe to WebSocket progress stream from Rust backend
    const unsubscribe = subscribeProgress((evt) => {
      progressEvents = [...progressEvents, evt];
      currentStageMessage = evt.message;
    });

    try {
      // Post document stream to Rust Axum /analyze endpoint
      const resultReport = await analyzeDocument(fileData, filename, 'auto');
      report = resultReport;
    } catch (err: any) {
      console.error('Backend analysis error:', err);
      currentStageMessage = `ERROR: ${err.message}`;
      alert(`Document analysis failed: ${err.message}`);
      handleReset();
    } finally {
      setTimeout(() => {
        isScanning = false;
        unsubscribe();
      }, 600);
    }
  }

  function handleReset() {
    selectedFile = null;
    report = undefined;
    isScanning = false;
    progressEvents = [];
    currentStageMessage = '';
  }
</script>

<svelte:head>
  <title>KAGUA &bull; Compliance Intelligence Engine</title>
</svelte:head>

<div class="page-container">
  <HeaderSection
    {frameworks}
    onToggleFramework={toggleFramework}
  />

  {#if !selectedFile || isScanning}
    <DropZone
      {isScanning}
      {progressEvents}
      {currentStageMessage}
      onFileSelected={handleFileSelected}
    />
  {:else}
    <AnalysisResultView
      file={selectedFile}
      {report}
      {frameworks}
      onReset={handleReset}
    />
  {/if}
</div>

<style>
  .page-container {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
</style>
