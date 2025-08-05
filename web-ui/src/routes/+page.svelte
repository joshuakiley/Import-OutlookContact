<script lang="ts">
  import { onMount } from "svelte";

  let mounted = false;
  let systemStatus = {
    webInterface: "Online",
    authentication: "Ready",
    backend: "Connected",
    database: "Available",
  };

  onMount(() => {
    mounted = true;
  });
</script>

<svelte:head>
  <title>Import-OutlookContact Dashboard</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <header class="bg-white border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center h-16">
        <div class="flex items-center">
          <h1 class="text-2xl font-bold text-primary-600">
            📱 Import-OutlookContact
          </h1>
          <span
            class="ml-3 px-2 py-1 text-xs font-medium bg-success-100 text-success-800 rounded-full"
          >
            Svelte + TypeScript
          </span>
        </div>
        <div class="flex items-center space-x-4">
          <span
            class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-success-100 text-success-800"
          >
            🟢 System Online
          </span>
          <button class="btn-primary"> Login </button>
        </div>
      </div>
    </div>
  </header>

  <!-- Main Content -->
  <main class="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
    <!-- Welcome Banner -->
    <div
      class="bg-gradient-to-r from-primary-600 to-primary-700 rounded-lg p-8 text-white mb-8"
    >
      <h2 class="text-3xl font-bold mb-2">
        🚀 Welcome to Import-OutlookContact
      </h2>
      <p class="text-lg opacity-90">
        Enterprise-grade contact management with modern web technologies
      </p>
      <p class="text-sm opacity-80 mt-2">
        Built with Svelte + TailwindCSS + TypeScript for maximum security and
        performance
      </p>
    </div>

    <!-- Quick Actions Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <!-- Import Contacts -->
      <div class="card p-6 hover:shadow-md transition-shadow duration-200">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">
            📂 Import Contacts
          </h3>
          <div
            class="w-10 h-10 bg-primary-100 rounded-lg flex items-center justify-center"
          >
            <span class="text-primary-600 text-xl">📁</span>
          </div>
        </div>
        <p class="text-gray-600 text-sm mb-4">
          Upload CSV, vCard, or other contact files with secure validation
        </p>
        <button class="btn-primary w-full" disabled>
          Start Import Wizard
        </button>
      </div>

      <!-- Backup & Restore -->
      <div class="card p-6 hover:shadow-md transition-shadow duration-200">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">
            💾 Backup & Restore
          </h3>
          <div
            class="w-10 h-10 bg-success-100 rounded-lg flex items-center justify-center"
          >
            <span class="text-success-600 text-xl">💾</span>
          </div>
        </div>
        <p class="text-gray-600 text-sm mb-4">
          Secure backup and point-in-time recovery with encryption
        </p>
        <button class="btn-success w-full" disabled> Backup Manager </button>
      </div>

      <!-- Duplicate Detection -->
      <div class="card p-6 hover:shadow-md transition-shadow duration-200">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">
            🔍 Find Duplicates
          </h3>
          <div
            class="w-10 h-10 bg-warning-100 rounded-lg flex items-center justify-center"
          >
            <span class="text-warning-600 text-xl">🔍</span>
          </div>
        </div>
        <p class="text-gray-600 text-sm mb-4">
          AI-powered duplicate detection with smart merging
        </p>
        <button class="btn-warning w-full" disabled> Duplicate Scanner </button>
      </div>

      <!-- Analytics -->
      <div class="card p-6 hover:shadow-md transition-shadow duration-200">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">📊 Analytics</h3>
          <div
            class="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center"
          >
            <span class="text-purple-600 text-xl">📊</span>
          </div>
        </div>
        <p class="text-gray-600 text-sm mb-4">
          Real-time dashboards and comprehensive reporting
        </p>
        <button class="btn-secondary w-full" disabled> View Dashboard </button>
      </div>
    </div>

    <!-- System Status -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
      <!-- Status Overview -->
      <div class="card">
        <div class="p-6 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">🖥️ System Status</h3>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            {#each Object.entries(systemStatus) as [component, status]}
              <div class="flex items-center justify-between py-2">
                <span class="text-sm font-medium text-gray-700 capitalize">
                  {component.replace(/([A-Z])/g, " $1").trim()}
                </span>
                <span
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-success-100 text-success-800"
                >
                  ✅ {status}
                </span>
              </div>
            {/each}
          </div>
        </div>
      </div>

      <!-- Technology Stack -->
      <div class="card">
        <div class="p-6 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">
            🛠️ Technology Stack
          </h3>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div class="flex items-center space-x-3">
              <div
                class="w-8 h-8 bg-orange-100 rounded-lg flex items-center justify-center"
              >
                <span class="text-orange-600 text-sm font-bold">S</span>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Svelte 4+</p>
                <p class="text-xs text-gray-500">Reactive frontend framework</p>
              </div>
            </div>

            <div class="flex items-center space-x-3">
              <div
                class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center"
              >
                <span class="text-blue-600 text-sm font-bold">T</span>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">TailwindCSS 3+</p>
                <p class="text-xs text-gray-500">Utility-first CSS framework</p>
              </div>
            </div>

            <div class="flex items-center space-x-3">
              <div
                class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center"
              >
                <span class="text-blue-600 text-sm font-bold">TS</span>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">TypeScript 5+</p>
                <p class="text-xs text-gray-500">Type-safe JavaScript</p>
              </div>
            </div>

            <div class="flex items-center space-x-3">
              <div
                class="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center"
              >
                <span class="text-purple-600 text-sm font-bold">PS</span>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">PowerShell 7+</p>
                <p class="text-xs text-gray-500">Cross-platform backend</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Security Notice -->
    <div class="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-6">
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <span class="text-blue-500 text-xl">🛡️</span>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-blue-800">
            Security-First Implementation
          </h3>
          <div class="mt-2 text-sm text-blue-700">
            <ul class="list-disc list-inside space-y-1">
              <li>All user input sanitized and validated with Zod schemas</li>
              <li>
                XSS prevention using DOMPurify and Svelte's built-in escaping
              </li>
              <li>CSRF protection with secure headers and token validation</li>
              <li>File upload validation with type/size restrictions</li>
              <li>OAuth 2.0 authentication with Microsoft Graph integration</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </main>

  <!-- Footer -->
  <footer class="bg-white border-t border-gray-200 mt-16">
    <div class="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
      <div class="text-center text-sm text-gray-500">
        <p>
          Import-OutlookContact v1.0.0-security | Built with security-first
          principles | Enterprise-grade contact management
        </p>
        <p class="mt-2">
          🔒 All operations are logged and audited | 📞 <a
            href="mailto:support@company.com"
            class="text-primary-600 hover:text-primary-800">Support</a
          >
          | 📚
          <a href="/docs" class="text-primary-600 hover:text-primary-800"
            >Documentation</a
          >
        </p>
      </div>
    </div>
  </footer>
</div>

<style>
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.5rem 1rem;
    font-size: 0.875rem;
    font-weight: 500;
    border-radius: 0.5rem;
    transition: all 0.2s;
    border: none;
    cursor: pointer;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-primary {
    background-color: #2563eb;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background-color: #1d4ed8;
  }

  .btn-success {
    background-color: #16a34a;
    color: white;
  }

  .btn-success:hover:not(:disabled) {
    background-color: #15803d;
  }

  .btn-warning {
    background-color: #d97706;
    color: white;
  }

  .btn-warning:hover:not(:disabled) {
    background-color: #b45309;
  }

  .btn-secondary {
    background-color: #e5e7eb;
    color: #374151;
  }

  .btn-secondary:hover:not(:disabled) {
    background-color: #d1d5db;
  }

  .card {
    background-color: white;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
    box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  }

  .text-primary-600 {
    color: #2563eb;
  }

  .bg-primary-600 {
    background-color: #2563eb;
  }

  .bg-primary-700 {
    background-color: #1d4ed8;
  }
</style>
