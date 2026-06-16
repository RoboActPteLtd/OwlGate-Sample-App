<script lang="ts">
  import Toast from "$lib/Toast.svelte";

  let name = $state("");
  let email = $state("");
  let message = $state("");

  async function submit(event: SubmitEvent) {
    event.preventDefault();
    const res = await fetch("/api/contacts", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name, email }),
    });
    if (res.ok) {
      // Defect #2 (flaky timing): the toast animates in over ~400ms; a test that
      // waits too little asserts before it is visible and fails intermittently.
      await new Promise((r) => setTimeout(r, 400));
      message = "Thanks, we'll be in touch";
    }
  }
</script>

<h1>Contact us</h1>

<form onsubmit={submit}>
  <label>Name <input bind:value={name} name="name" /></label>
  <label>Email <input bind:value={email} name="email" /></label>
  <button type="submit">Submit</button>
</form>

<Toast {message} />
