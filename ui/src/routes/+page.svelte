<script lang="ts">
  import HeaderSection from '$lib/components/HeaderSection.svelte';
  import DropZone from '$lib/components/DropZone.svelte';
  import AnalysisResultView from '$lib/components/AnalysisResultView.svelte';
  import { INITIAL_FRAMEWORKS, SAMPLE_DOCS, type Framework, type SampleDoc } from '$lib/data/sampleDocs';

  let frameworks = $state<Framework[]>(INITIAL_FRAMEWORKS);
  let isScanning = $state(false);
  let selectedFile = $state<{ name: string; size: string; type: string; content?: string; sampleId?: string } | null>(null);
  let sampleDoc = $state<SampleDoc | undefined>(undefined);

  function toggleFramework(id: string) {
    frameworks = frameworks.map(fw =>
      fw.id === id ? { ...fw, active: !fw.active } : fw
    );
  }

  function handleFileSelected(file: { name: string; size: string; type: string; content?: string; sampleId?: string }) {
    selectedFile = file;
    if (file.sampleId) {
      sampleDoc = SAMPLE_DOCS.find(s => s.id === file.sampleId);
    } else {
      sampleDoc = undefined;
    }

    isScanning = true;
    setTimeout(() => {
      isScanning = false;
    }, 1400);
  }

  function handleReset() {
    selectedFile = null;
    sampleDoc = undefined;
    isScanning = false;
  }
</script>

<svelte:head>
  <title>COMPLIANCE CHECK &bull; Document Intelligence</title>
</svelte:head>

<div class="page-container">
  <!-- Header Section with precise typography and active frameworks row -->
  <HeaderSection
    {frameworks}
    onToggleFramework={toggleFramework}
  />

  <!-- Main Work Area: Dropzone or Scan Results -->
  {#if !selectedFile || isScanning}
    <DropZone
      {isScanning}
      onFileSelected={handleFileSelected}
    />
  {:else}
    <AnalysisResultView
      file={selectedFile}
      {frameworks}
      {sampleDoc}
      onReset={handleReset}
    />
  {/if}
</div>

<style>
  .page-container {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
</style>
