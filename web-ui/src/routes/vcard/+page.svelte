<script lang="ts">
  import { onMount } from "svelte";
  import type {
    VCardImportResponse,
    VCardValidationResult,
  } from "$lib/types/vcard";

  // State management
  let selectedFile: File | null = null;
  let dragOver = false;
  let isValidating = false;
  let isImporting = false;
  let validationResult: VCardValidationResult | null = null;
  let importResult: VCardImportResponse | null = null;
  let showAdvanced = false;

  // Form data
  let userEmail = "";
  let contactFolder = "";
  let duplicateAction: "Skip" | "Merge" | "Overwrite" | "Consolidate" = "Merge";
  let validateOnly = true;
  let enhancedParsing = true;

  // File validation
  function validateFile(file: File): string | null {
    if (file.size > 50 * 1024 * 1024) {
      return "File size must be less than 50MB";
    }

    const validExtensions = [".vcf", ".vcard"];
    const fileName = file.name.toLowerCase();
    const isValidExtension = validExtensions.some((ext) =>
      fileName.endsWith(ext)
    );

    if (!isValidExtension) {
      return "File must be a vCard (.vcf or .vcard) file";
    }

    return null;
  }

  // File drop handling
  function handleDrop(event: DragEvent) {
    event.preventDefault();
    dragOver = false;

    const files = event.dataTransfer?.files;
    if (files && files.length > 0 && files[0]) {
      handleFileSelect(files[0]);
    }
  }

  function handleDragOver(event: DragEvent) {
    event.preventDefault();
    dragOver = true;
  }

  function handleDragLeave() {
    dragOver = false;
  }

  function handleFileInput(event: Event) {
    const target = event.target as HTMLInputElement;
    if (target.files && target.files.length > 0 && target.files[0]) {
      handleFileSelect(target.files[0]);
    }
  }

  function handleFileSelect(file: File) {
    const validationError = validateFile(file);
    if (validationError) {
      alert(validationError);
      return;
    }

    selectedFile = file;
    validationResult = null;
    importResult = null;
  }

  // Mock API calls (replace with actual backend integration)
  async function validateVCard(): Promise<VCardValidationResult> {
    // This would call your PowerShell backend
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          isValid: true,
          vCardVersion: "3.0",
          contactCount: 99,
          statistics: {
            emailsFound: 43,
            phonesFound: 96,
            addressesFound: 0,
            companiesFound: 78,
            duplicateEmails: 0,
          },
          warnings: ["Some contacts missing mobile phone numbers"],
        });
      }, 2000);
    });
  }

  async function importVCard(): Promise<VCardImportResponse> {
    // This would call your PowerShell backend
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          success: true,
          message: "Successfully imported contacts",
          totalContacts: 99,
          validContacts: 99,
          invalidContacts: 0,
          duplicatesFound: 5,
          contactsProcessed: 94,
        });
      }, 3000);
    });
  }

  async function handleValidate() {
    if (!selectedFile || !userEmail) return;

    isValidating = true;
    try {
      validationResult = await validateVCard();
    } catch (error) {
      console.error("Validation failed:", error);
      alert("Validation failed. Please try again.");
    } finally {
      isValidating = false;
    }
  }

  async function handleImport() {
    if (!selectedFile || !userEmail) return;

    isImporting = true;
    try {
      importResult = await importVCard();
    } catch (error) {
      console.error("Import failed:", error);
      alert("Import failed. Please try again.");
    } finally {
      isImporting = false;
    }
  }

  function resetForm() {
    selectedFile = null;
    validationResult = null;
    importResult = null;
    validateOnly = true;
  }

  onMount(() => {
    // Initialize with default user email if available
    userEmail = "user@example.com"; // This would come from authentication
  });
</script>

<svelte:head>
  <title>vCard Import - Import-OutlookContact</title>
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <header class="bg-white border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center h-16">
        <div class="flex items-center">
          <h1 class="text-2xl font-bold text-blue-600">📱 vCard Import</h1>
          <span
            class="ml-3 px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded-full"
          >
            Enhanced Parser
          </span>
        </div>
        <div class="flex items-center space-x-4">
          <a href="/" class="text-gray-600 hover:text-gray-900"
            >← Back to Dashboard</a
          >
        </div>
      </div>
    </div>
  </header>

  <!-- Main Content -->
  <main class="max-w-4xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
    <!-- Progress Steps -->
    <div class="mb-8">
      <div class="flex items-center justify-between">
        <div class="flex items-center">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-600 text-white text-sm font-medium"
          >
            1
          </div>
          <span class="ml-2 text-sm font-medium text-gray-900">Upload File</span
          >
        </div>
        <div class="flex-1 mx-4 h-0.5 bg-gray-300"></div>
        <div class="flex items-center">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-full {validationResult
              ? 'bg-blue-600 text-white'
              : 'bg-gray-300 text-gray-500'} text-sm font-medium"
          >
            2
          </div>
          <span
            class="ml-2 text-sm font-medium {validationResult
              ? 'text-gray-900'
              : 'text-gray-500'}">Validate</span
          >
        </div>
        <div class="flex-1 mx-4 h-0.5 bg-gray-300"></div>
        <div class="flex items-center">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-full {importResult
              ? 'bg-green-600 text-white'
              : 'bg-gray-300 text-gray-500'} text-sm font-medium"
          >
            3
          </div>
          <span
            class="ml-2 text-sm font-medium {importResult
              ? 'text-gray-900'
              : 'text-gray-500'}">Import</span
          >
        </div>
      </div>
    </div>

    <!-- File Upload -->
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">
        📂 Select vCard File
      </h2>

      <!-- Drag & Drop Area -->
      <div
        class="border-2 border-dashed {dragOver
          ? 'border-blue-400 bg-blue-50'
          : 'border-gray-300'} rounded-lg p-8 text-center transition-colors"
        on:drop={handleDrop}
        on:dragover={handleDragOver}
        on:dragleave={handleDragLeave}
        role="button"
        tabindex="0"
      >
        {#if selectedFile}
          <div class="flex items-center justify-center mb-4">
            <div
              class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center"
            >
              <span class="text-blue-600 text-2xl">📋</span>
            </div>
          </div>
          <p class="text-lg font-medium text-gray-900">{selectedFile.name}</p>
          <p class="text-sm text-gray-500">
            {(selectedFile.size / 1024).toFixed(1)} KB • {selectedFile.type ||
              "vCard file"}
          </p>
          <button
            class="mt-4 text-blue-600 hover:text-blue-800 text-sm font-medium"
            on:click={resetForm}
          >
            Choose different file
          </button>
        {:else}
          <div class="flex items-center justify-center mb-4">
            <div
              class="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center"
            >
              <span class="text-gray-400 text-2xl">📁</span>
            </div>
          </div>
          <p class="text-lg font-medium text-gray-900 mb-2">
            Drag and drop your vCard file here
          </p>
          <p class="text-sm text-gray-500 mb-4">
            Supports .vcf and .vcard files up to 50MB
          </p>
          <label class="cursor-pointer">
            <span
              class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
            >
              Browse Files
            </span>
            <input
              type="file"
              class="hidden"
              accept=".vcf,.vcard,text/vcard,text/x-vcard"
              on:change={handleFileInput}
            />
          </label>
        {/if}
      </div>
    </div>

    <!-- Import Settings -->
    {#if selectedFile}
      <div
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6"
      >
        <h2 class="text-lg font-semibold text-gray-900 mb-4">
          ⚙️ Import Settings
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- User Email -->
          <div>
            <label
              for="userEmail"
              class="block text-sm font-medium text-gray-700 mb-1"
            >
              User Email
            </label>
            <input
              id="userEmail"
              type="email"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              bind:value={userEmail}
              placeholder="user@example.com"
              required
            />
          </div>

          <!-- Contact Folder -->
          <div>
            <label
              for="contactFolder"
              class="block text-sm font-medium text-gray-700 mb-1"
            >
              Contact Folder (Optional)
            </label>
            <input
              id="contactFolder"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              bind:value={contactFolder}
              placeholder="iPhone Contacts"
            />
          </div>

          <!-- Duplicate Action -->
          <div>
            <label
              for="duplicateAction"
              class="block text-sm font-medium text-gray-700 mb-1"
            >
              Duplicate Handling
            </label>
            <select
              id="duplicateAction"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              bind:value={duplicateAction}
            >
              <option value="Skip">Skip Duplicates</option>
              <option value="Merge">Merge Information</option>
              <option value="Overwrite">Overwrite Existing</option>
              <option value="Consolidate">Consolidate Contacts</option>
            </select>
          </div>

          <!-- Enhanced Parsing -->
          <div class="flex items-center">
            <input
              id="enhancedParsing"
              type="checkbox"
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              bind:checked={enhancedParsing}
            />
            <label
              for="enhancedParsing"
              class="ml-2 text-sm font-medium text-gray-700"
            >
              Use Enhanced Parsing (Recommended for iPhone)
            </label>
          </div>
        </div>

        <!-- Advanced Options Toggle -->
        <button
          class="mt-4 text-blue-600 hover:text-blue-800 text-sm font-medium"
          on:click={() => (showAdvanced = !showAdvanced)}
        >
          {showAdvanced ? "▼" : "▶"} Advanced Options
        </button>

        {#if showAdvanced}
          <div class="mt-4 p-4 bg-gray-50 rounded-md">
            <div class="flex items-center">
              <input
                id="validateOnly"
                type="checkbox"
                class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                bind:checked={validateOnly}
              />
              <label
                for="validateOnly"
                class="ml-2 text-sm font-medium text-gray-700"
              >
                Validation Only Mode (Safe testing without importing)
              </label>
            </div>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Action Buttons -->
    {#if selectedFile && userEmail}
      <div class="flex space-x-4 mb-6">
        <button
          class="bg-blue-600 text-white px-6 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          on:click={handleValidate}
          disabled={isValidating || isImporting}
        >
          {#if isValidating}
            <div
              class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"
            ></div>
          {/if}
          🔍 Validate vCard
        </button>

        {#if validationResult && !validateOnly}
          <button
            class="bg-green-600 text-white px-6 py-2 rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
            on:click={handleImport}
            disabled={isImporting || isValidating}
          >
            {#if isImporting}
              <div
                class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"
              ></div>
            {/if}
            📥 Import Contacts
          </button>
        {/if}
      </div>
    {/if}

    <!-- Validation Results -->
    {#if validationResult}
      <div
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6"
      >
        <h2 class="text-lg font-semibold text-gray-900 mb-4">
          📊 Validation Results
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div class="text-center p-4 bg-blue-50 rounded-lg">
            <div class="text-2xl font-bold text-blue-600">
              {validationResult.contactCount}
            </div>
            <div class="text-sm text-gray-600">Total Contacts</div>
          </div>
          <div class="text-center p-4 bg-green-50 rounded-lg">
            <div class="text-2xl font-bold text-green-600">
              {validationResult.statistics?.emailsFound || 0}
            </div>
            <div class="text-sm text-gray-600">Email Addresses</div>
          </div>
          <div class="text-center p-4 bg-purple-50 rounded-lg">
            <div class="text-2xl font-bold text-purple-600">
              {validationResult.statistics?.companiesFound || 0}
            </div>
            <div class="text-sm text-gray-600">Companies</div>
          </div>
        </div>

        {#if validationResult.statistics}
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              📞 Phone Numbers: {validationResult.statistics.phonesFound}
            </div>
            <div>
              🏠 Addresses: {validationResult.statistics.addressesFound}
            </div>
          </div>
        {/if}

        {#if validationResult.warnings && validationResult.warnings.length > 0}
          <div class="mt-4">
            <h3 class="font-medium text-yellow-800 mb-2">⚠️ Warnings:</h3>
            <ul class="text-sm text-yellow-700 space-y-1">
              {#each validationResult.warnings as warning}
                <li>• {warning}</li>
              {/each}
            </ul>
          </div>
        {/if}
      </div>
    {/if}

    <!-- Import Results -->
    {#if importResult}
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">
          {importResult.success ? "✅" : "❌"} Import Results
        </h2>

        {#if importResult.success}
          <div class="bg-green-50 border border-green-200 rounded-md p-4 mb-4">
            <p class="text-green-800 font-medium">{importResult.message}</p>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <div class="font-medium text-gray-900">
                {importResult.contactsProcessed}
              </div>
              <div class="text-gray-600">Contacts Imported</div>
            </div>
            <div>
              <div class="font-medium text-gray-900">
                {importResult.duplicatesFound}
              </div>
              <div class="text-gray-600">Duplicates Handled</div>
            </div>
            <div>
              <div class="font-medium text-gray-900">
                {importResult.validContacts}
              </div>
              <div class="text-gray-600">Valid Contacts</div>
            </div>
            <div>
              <div class="font-medium text-gray-900">
                {importResult.invalidContacts}
              </div>
              <div class="text-gray-600">Invalid Contacts</div>
            </div>
          </div>
        {:else}
          <div class="bg-red-50 border border-red-200 rounded-md p-4">
            <p class="text-red-800 font-medium">{importResult.message}</p>
          </div>
        {/if}
      </div>
    {/if}
  </main>
</div>
