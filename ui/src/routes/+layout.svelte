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
		justify-content: center;
		padding: 2rem 1rem;
	}

	.app-main {
		position: relative;
		z-index: 1;
		width: 100%;
		max-width: 960px;
		margin: 0 auto;
	}
</style>
