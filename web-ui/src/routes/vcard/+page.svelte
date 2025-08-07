<script lang="ts">
  import type {
    VCardImportResponse,
    VCardValidationResult,
    ContactFolder,
  } from "$lib/types/vcard";
  import {
    importVCard as importVCardAPI,
    getUserFolders,
    createContactFolder,
    type VCardImportRequest,
    type CreateFolderRequest,
  } from "$lib/utils/api";

  // State management
  let selectedFile: File | null = null;
  let dragOver = false;
  let isValidating = false;
  let isImporting = false;
  let validationResult: VCardValidationResult | null = null;
  let importResult: VCardImportResponse | null = null;
  let errorMessage = "";

  // Folder management
  let userFolders: ContactFolder[] = [];
  let isLoadingFolders = false;
  let showCreateFolder = false;
  let newFolderName = "";
  let isCreatingFolder = false;

  // Form data
  let userEmail = "";
  let contactFolder = "";
  let duplicateAction: "Skip" | "Merge" | "Overwrite" | "Consolidate" = "Merge";
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

  // Reset state
  function resetState() {
    validationResult = null;
    importResult = null;
    errorMessage = "";
  }

  // Folder management functions
  async function loadUserFolders() {
    if (!userEmail) return;

    isLoadingFolders = true;
    try {
      const result = await getUserFolders(userEmail);
      if (result.success) {
        userFolders = result.folders;
      } else {
        errorMessage = result.error || "Failed to load folders";
      }
    } catch (error) {
      console.error("Failed to load folders:", error);
      errorMessage =
        error instanceof Error ? error.message : "Failed to load folders";
    } finally {
      isLoadingFolders = false;
    }
  }

  async function createNewFolder() {
    if (!userEmail || !newFolderName.trim()) return;

    isCreatingFolder = true;
    try {
      const request: CreateFolderRequest = {
        userEmail,
        folderName: newFolderName.trim(),
      };

      const result = await createContactFolder(request);
      if (result.success && result.folder) {
        userFolders = [...userFolders, result.folder];
        contactFolder = result.folder.DisplayName;
        newFolderName = "";
        showCreateFolder = false;
      } else {
        errorMessage = result.error || "Failed to create folder";
      }
    } catch (error) {
      console.error("Failed to create folder:", error);
      errorMessage =
        error instanceof Error ? error.message : "Failed to create folder";
    } finally {
      isCreatingFolder = false;
    }
  }

  // Watch for userEmail changes to load folders
  $: if (userEmail && userEmail.includes("@")) {
    loadUserFolders();
  }

  // Real API calls to backend
  async function handleValidate() {
    if (!selectedFile) return;

    isValidating = true;
    resetState();

    try {
      const request: VCardImportRequest = {
        file: selectedFile,
        duplicateAction,
        validateOnly: true,
        enhancedParsing,
      };

      if (userEmail) request.userEmail = userEmail;
      if (contactFolder) request.contactFolder = contactFolder;

      const result = await importVCardAPI(request);

      // Convert API response to validation result format
      validationResult = {
        isValid: result.isValid,
        vCardVersion: result.vCardVersion || "Unknown",
        contactCount: result.contactCount,
        statistics: result.statistics,
        warnings: result.warnings,
      };

      if (result.error) {
        errorMessage = result.error;
      }
    } catch (error) {
      console.error("Validation failed:", error);
      errorMessage =
        error instanceof Error
          ? error.message
          : "Validation failed. Please try again.";
    } finally {
      isValidating = false;
    }
  }

  async function handleImport() {
    if (!selectedFile) return;

    isImporting = true;
    resetState();

    try {
      const request: VCardImportRequest = {
        file: selectedFile,
        duplicateAction,
        validateOnly: false,
        enhancedParsing,
      };

      if (userEmail) request.userEmail = userEmail;
      if (contactFolder) request.contactFolder = contactFolder;

      const result = await importVCardAPI(request);

      // Convert API response to import result format
      importResult = {
        success: result.isValid && !result.error,
        message: result.error || "Import completed successfully",
        totalContacts: result.contactCount,
        validContacts:
          (result.importedContacts || 0) + (result.skippedContacts || 0),
        invalidContacts: result.errorContacts || 0,
        duplicatesFound: result.skippedContacts || 0,
        contactsProcessed: result.importedContacts || 0,
      };

      if (result.error) {
        errorMessage = result.error;
      }
    } catch (error) {
      console.error("Import failed:", error);
      errorMessage =
        error instanceof Error
          ? error.message
          : "Import failed. Please try again.";
      importResult = {
        success: false,
        message: "Import failed",
        totalContacts: 0,
        validContacts: 0,
        invalidContacts: 0,
        duplicatesFound: 0,
        contactsProcessed: 0,
      };
    } finally {
      isImporting = false;
    }
  }

  function clearFile() {
    selectedFile = null;
    validationResult = null;
    importResult = null;
    errorMessage = "";
  }
</script>

<svelte:head>
  <title>vCard Import - Import-OutlookContact</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
    <!-- Header -->
    <div class="mb-8">
      <nav class="flex" aria-label="Breadcrumb">
        <ol class="flex items-center space-x-4">
          <li>
            <a href="/" class="text-primary-600 hover:text-primary-700">
              Dashboard
            </a>
          </li>
          <li class="text-gray-500">/</li>
          <li class="text-gray-900 font-medium">vCard Import</li>
        </ol>
      </nav>
      <h1 class="mt-4 text-3xl font-bold text-gray-900">📱 vCard Import</h1>
      <p class="mt-2 text-lg text-gray-600">
        Import contacts from vCard (.vcf) files with advanced parsing and
        duplicate handling
      </p>
    </div>

    <!-- Main Content -->
    <div class="space-y-6">
      <!-- File Upload -->
      {#if !selectedFile}
        <div class="card p-8">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">
            📁 Upload vCard File
          </h2>

          <!-- Drag & Drop Area -->
          <div
            class="border-2 border-dashed border-gray-300 rounded-lg p-12 text-center hover:border-primary-400 transition-colors {dragOver
              ? 'border-primary-500 bg-primary-50'
              : ''}"
            on:drop={handleDrop}
            on:dragover={handleDragOver}
            on:dragleave={handleDragLeave}
            role="button"
            tabindex="0"
          >
            <div class="text-6xl mb-4">📱</div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">
              Drop your vCard file here
            </h3>
            <p class="text-gray-600 mb-4">
              or click to browse for .vcf or .vcard files
            </p>
            <input
              type="file"
              accept=".vcf,.vcard"
              on:change={handleFileInput}
              class="hidden"
              id="fileInput"
            />
            <label for="fileInput" class="btn-primary cursor-pointer">
              📂 Choose File
            </label>
            <p class="text-xs text-gray-500 mt-3">Maximum file size: 50MB</p>
          </div>
        </div>
      {/if}

      <!-- File Selected and Actions -->
      {#if selectedFile}
        <div class="card p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold text-gray-900">
              📄 {selectedFile.name}
            </h2>
            <button
              on:click={clearFile}
              class="text-sm text-red-600 hover:text-red-700"
            >
              ✕ Remove
            </button>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Form Configuration -->
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-gray-900">Configuration</h3>

              <div>
                <label
                  for="userEmail"
                  class="block text-sm font-medium text-gray-700 mb-1"
                >
                  User Email {#if !userEmail}<span class="text-red-500">*</span
                    >{/if}
                </label>
                <input
                  type="email"
                  id="userEmail"
                  bind:value={userEmail}
                  placeholder="user@company.com"
                  class="input-field"
                  required
                />
                {#if userEmail && !userEmail.includes("@")}
                  <p class="text-xs text-gray-500 mt-1">
                    Enter a valid email to load your contact folders
                  </p>
                {:else if userEmail && userEmail.includes("@") && userFolders.length > 0}
                  <p class="text-xs text-green-600 mt-1">
                    ✅ Loaded {userFolders.length} contact folders
                  </p>
                {/if}
              </div>

              <div>
                <label
                  for="duplicateAction"
                  class="block text-sm font-medium text-gray-700 mb-1"
                >
                  Duplicate Handling
                </label>
                <select
                  id="duplicateAction"
                  bind:value={duplicateAction}
                  class="input-field"
                >
                  <option value="Skip">Skip duplicates</option>
                  <option value="Merge">Compare and merge</option>
                  <option value="Overwrite">Overwrite existing</option>
                  <option value="Consolidate">Consolidate all data</option>
                </select>

                <!-- Duplicate Action Descriptions -->
                <div class="mt-2 text-xs text-gray-600">
                  {#if duplicateAction === "Skip"}
                    <p>
                      🚫 Skip importing contacts that already exist anywhere
                    </p>
                  {:else if duplicateAction === "Merge"}
                    <div class="space-y-1">
                      <p>
                        🔍 <strong>Interactive comparison</strong> - Choose which
                        data to keep from each contact
                      </p>
                      <p class="text-blue-600">
                        📂 <strong>Folder selection:</strong> Choose which folder
                        to place the merged contact in
                      </p>
                    </div>
                  {:else if duplicateAction === "Overwrite"}
                    <p>⚠️ Completely replace existing contacts with new data</p>
                  {:else if duplicateAction === "Consolidate"}
                    <p>
                      🗂️ Automatically combine data and move to target folder,
                      removing duplicates from other folders
                    </p>
                  {/if}
                </div>
              </div>

              <!-- Contact Folder Selection -->
              <div>
                <label
                  for="contactFolder"
                  class="block text-sm font-medium text-gray-700 mb-1"
                >
                  Contact Folder
                </label>
                <div class="space-y-2">
                  <div class="flex gap-2">
                    <select
                      id="contactFolder"
                      bind:value={contactFolder}
                      class="input-field flex-1"
                      disabled={isLoadingFolders}
                    >
                      <option value="">Default (Contacts)</option>
                      {#each userFolders as folder}
                        <option value={folder.DisplayName}>
                          {folder.DisplayName}
                          {folder.IsDefault ? " (Default)" : ""}
                        </option>
                      {/each}
                    </select>
                    <button
                      type="button"
                      on:click={() => (showCreateFolder = !showCreateFolder)}
                      class="btn-secondary px-3 py-2 text-sm"
                      disabled={!userEmail}
                    >
                      ➕ New
                    </button>
                  </div>

                  {#if isLoadingFolders}
                    <p class="text-xs text-gray-500">Loading folders...</p>
                  {/if}

                  <!-- Create New Folder -->
                  {#if showCreateFolder}
                    <div class="bg-gray-50 rounded-lg p-3 border">
                      <div class="flex gap-2">
                        <input
                          type="text"
                          bind:value={newFolderName}
                          placeholder="Enter folder name"
                          class="input-field flex-1 text-sm"
                          disabled={isCreatingFolder}
                        />
                        <button
                          type="button"
                          on:click={createNewFolder}
                          disabled={!newFolderName.trim() || isCreatingFolder}
                          class="btn-primary px-3 py-1 text-sm"
                        >
                          {#if isCreatingFolder}
                            ⏳
                          {:else}
                            Create
                          {/if}
                        </button>
                        <button
                          type="button"
                          on:click={() => {
                            showCreateFolder = false;
                            newFolderName = "";
                          }}
                          class="btn-secondary px-3 py-1 text-sm"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  {/if}
                </div>
              </div>

              <label class="flex items-center">
                <input
                  type="checkbox"
                  bind:checked={enhancedParsing}
                  class="rounded text-primary-600 mr-2"
                />
                <span class="text-sm text-gray-700"
                  >Enhanced iPhone parsing</span
                >
              </label>
            </div>

            <!-- Actions -->
            <div class="space-y-4">
              <h3 class="text-lg font-medium text-gray-900">Actions</h3>

              <button
                on:click={handleValidate}
                disabled={isValidating || !userEmail}
                class="btn-secondary w-full {isValidating || !userEmail
                  ? 'opacity-50 cursor-not-allowed'
                  : ''}"
              >
                {#if isValidating}
                  🔄 Validating...
                {:else}
                  ✅ Validate Only
                {/if}
              </button>

              <button
                on:click={handleImport}
                disabled={isImporting || !validationResult || !userEmail}
                class="btn-primary w-full {isImporting ||
                !validationResult ||
                !userEmail
                  ? 'opacity-50 cursor-not-allowed'
                  : ''}"
              >
                {#if isImporting}
                  📤 Importing...
                {:else}
                  📤 Import Contacts
                {/if}
              </button>

              <div class="text-xs text-gray-500 text-center space-y-1">
                {#if !userEmail}
                  <p class="text-red-500">⚠️ User email required</p>
                {:else if !validationResult}
                  <p>Please validate the file first</p>
                {:else}
                  <p class="text-green-600">✅ Ready to import</p>
                {/if}
              </div>
            </div>
          </div>
        </div>
      {/if}

      <!-- Validation Results -->
      {#if validationResult}
        <div class="card p-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">
            ✅ Validation Results
          </h2>

          <div
            class="bg-success-50 border border-success-200 rounded-lg p-4 mb-4"
          >
            <div class="flex items-center">
              <div class="text-success-600 text-xl mr-3">✅</div>
              <div>
                <h3 class="text-sm font-medium text-success-800">
                  File Validation Successful
                </h3>
                <p class="text-sm text-success-700 mt-1">
                  vCard {validationResult.vCardVersion} • {validationResult.contactCount}
                  contacts found
                </p>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-primary-600">
                {validationResult.statistics?.emailsFound || 0}
              </div>
              <div class="text-sm text-gray-600">Emails</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-primary-600">
                {validationResult.statistics?.phonesFound || 0}
              </div>
              <div class="text-sm text-gray-600">Phones</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-primary-600">
                {validationResult.statistics?.companiesFound || 0}
              </div>
              <div class="text-sm text-gray-600">Companies</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-primary-600">
                {validationResult.statistics?.addressesFound || 0}
              </div>
              <div class="text-sm text-gray-600">Addresses</div>
            </div>
          </div>

          {#if validationResult.warnings && validationResult.warnings.length > 0}
            <div
              class="mt-4 bg-warning-50 border border-warning-200 rounded-lg p-4"
            >
              <h4 class="text-sm font-medium text-warning-800 mb-2">
                ⚠️ Warnings
              </h4>
              <ul class="text-sm text-warning-700 space-y-1">
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
        <div class="card p-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">
            📊 Import Results
          </h2>

          <div
            class="border rounded-lg p-4 mb-4 {importResult.success
              ? 'bg-success-50 border-success-200'
              : 'bg-error-50 border-error-200'}"
          >
            <div class="flex items-center">
              <div
                class="text-xl mr-3 {importResult.success
                  ? 'text-success-600'
                  : 'text-error-600'}"
              >
                {importResult.success ? "✅" : "❌"}
              </div>
              <div>
                <h3
                  class="text-sm font-medium {importResult.success
                    ? 'text-success-800'
                    : 'text-error-800'}"
                >
                  {importResult.message}
                </h3>
                <p
                  class="text-sm mt-1 {importResult.success
                    ? 'text-success-700'
                    : 'text-error-700'}"
                >
                  {importResult.contactsProcessed} contacts imported
                </p>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-success-600">
                {importResult.contactsProcessed}
              </div>
              <div class="text-sm text-gray-600">Imported</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-warning-600">
                {importResult.duplicatesFound}
              </div>
              <div class="text-sm text-gray-600">Duplicates</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-primary-600">
                {importResult.validContacts}
              </div>
              <div class="text-sm text-gray-600">Valid</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-2xl font-bold text-error-600">
                {importResult.invalidContacts}
              </div>
              <div class="text-sm text-gray-600">Invalid</div>
            </div>
          </div>
        </div>
      {/if}

      <!-- Error Display -->
      {#if errorMessage}
        <div class="bg-error-50 border border-error-200 rounded-lg p-4">
          <div class="flex items-center">
            <div class="text-error-600 text-xl mr-3">❌</div>
            <div>
              <h3 class="text-sm font-medium text-error-800">Error</h3>
              <p class="text-sm text-error-700 mt-1">{errorMessage}</p>
            </div>
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>
