<script lang="ts">
  // Defect #1 (fragile selector): the test targets `.toast-success > span` rather
  // than a stable test id, so renaming/wrapping the text breaks the locator.
  let { message = "" }: { message?: string } = $props();
</script>

{#if message}
  <div class="toast-success" role="status">
    <span>{message}</span>
  </div>
{/if}

<style>
  .toast-success {
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    background: #e7f8ef;
    color: #0f5132;
  }
</style>
