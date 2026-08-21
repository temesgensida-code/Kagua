<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import '../app.css';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<div class="app-root">
	<div class="bg-grid"></div>
	<div class="bg-paper-texture"></div>
	<div class="bg-glow"></div>
	<main class="app-main">
		{@render children()}
	</main>
</div>

<style>
	.app-root {
		position: relative;
		min-height: 100vh;
		width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: flex-start;
		padding: 1rem 1rem 0.5rem 1rem;
		overflow-x: hidden;
	}

	.app-main {
		position: relative;
		z-index: 1;
		width: 100%;
		max-width: 1680px;
		margin: 0 auto;
		padding: 0 0.5rem;
		display: flex;
		flex-direction: column;
		flex: 1;
	}
</style>
