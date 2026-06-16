<script lang="ts">
  let { children } = $props();
</script>

<main style="max-width: 40rem; margin: 2rem auto; font-family: system-ui;">
  {@render children()}
</main>
