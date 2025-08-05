<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { authStore } from "$stores/auth";
  import type { LayoutData } from "./$types";

  export let data: LayoutData;

  // Security: Initialize authentication on app start
  onMount(async () => {
    try {
      await authStore.initialize();
    } catch (error) {
      console.error("Failed to initialize authentication:", error);
    }
  });
</script>

<svelte:head>
  <meta name="robots" content="noindex, nofollow, noarchive, nosnippet" />
</svelte:head>

<div class="min-h-full">
  <slot />
</div>

<style global>
  /* Custom scrollbar styling */
  ::-webkit-scrollbar {
    width: 6px;
    height: 6px;
  }

  ::-webkit-scrollbar-track {
    background: #f1f5f9;
  }

  ::-webkit-scrollbar-thumb {
    background: #cbd5e1;
    border-radius: 3px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: #94a3b8;
  }

  /* Focus styles for accessibility */
  .focus-visible {
    @apply outline-none ring-2 ring-primary-500 ring-offset-2;
  }

  /* Security: Hide sensitive content in print */
  @media print {
    .no-print {
      display: none !important;
    }
  }
</style>
