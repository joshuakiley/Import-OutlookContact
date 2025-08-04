<#
.SYNOPSIS
    Test-BackupOperation - Test backup functionality for Import-OutlookContact
    
.DESCRIPTION
    Tests the backup operation implementation to ensure it works correctly
    with Microsoft Graph API integration.
    
.PARAMETER TestUserEmail
    Test user's email address (default: current user)
    
.PARAMETER TestFolder
    Specific folder to test (optional)
    
.EXAMPLE
    pwsh .\test\Test-BackupOperation.ps1
    
.EXAMPLE
    pwsh .\test\Test-BackupOperation.ps1 -TestUserEmail "test@domain.com"
    
.NOTES
    Version: 1.0.0
    Requires: Microsoft.Graph module, Authentication module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestUserEmail = "",
    
    [Parameter(Mandatory = $false)]
    [string]$TestFolder = ""
)

Write-Information "=== Import-OutlookContact Backup Operation Test ===" -InformationAction Continue
Write-Information "" -InformationAction Continue

$testResults = @()
$allTestsPassed = $true

# Helper function to add test results
function Add-TestResult {
    param($TestName, $Status, $Message, $Details = @{})
    
    $script:testResults += @{
        Test = $TestName
        Status = $Status
        Message = $Message
        Details = $Details
    }
    
    $icon = switch ($Status) {
        "PASS" { "✅" }
        "FAIL" { "❌" }
        "WARNING" { "⚠️ " }
        "SKIP" { "⏭️ " }
    }
    
    Write-Information "$icon $TestName`: $Message" -InformationAction Continue
    
    if ($Status -eq "FAIL") {
        $script:allTestsPassed = $false
    }
}

try {
    # Get script directory for relative paths
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    
    Write-Information "Test Configuration:" -InformationAction Continue
    Write-Information "  Script Root: $scriptRoot" -InformationAction Continue
    Write-Information "  Test User: $(if($TestUserEmail) { $TestUserEmail } else { 'Current user' })" -InformationAction Continue
    Write-Information "  Test Folder: $(if($TestFolder) { $TestFolder } else { 'All folders' })" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    
    # Test 1: Module Import
    Write-Information "--- Testing Module Import ---" -InformationAction Continue
    
    try {
        $configModulePath = Join-Path $scriptRoot "modules" "Configuration.psm1"
        $authModulePath = Join-Path $scriptRoot "modules" "Authentication.psm1"
        $contactOpsModulePath = Join-Path $scriptRoot "modules" "ContactOperations.psm1"
        
        if (-not (Test-Path $configModulePath)) {
            Add-TestResult "Configuration Module" "FAIL" "Module file not found: $configModulePath"
        } else {
            Import-Module $configModulePath -Force -Verbose:$false
            Add-TestResult "Configuration Module" "PASS" "Module imported successfully"
        }
        
        if (-not (Test-Path $authModulePath)) {
            Add-TestResult "Authentication Module" "FAIL" "Module file not found: $authModulePath"
        } else {
            Import-Module $authModulePath -Force -Verbose:$false
            Add-TestResult "Authentication Module" "PASS" "Module imported successfully"
        }
        
        if (-not (Test-Path $contactOpsModulePath)) {
            Add-TestResult "ContactOperations Module" "FAIL" "Module file not found: $contactOpsModulePath"
        } else {
            Import-Module $contactOpsModulePath -Force -Verbose:$false
            Add-TestResult "ContactOperations Module" "PASS" "Module imported successfully"
        }
    }
    catch {
        Add-TestResult "Module Import" "FAIL" "Failed to import modules: $($_.Exception.Message)"
    }
    
    # Test 2: Configuration Loading
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Configuration ---" -InformationAction Continue
    
    try {
        $config = Initialize-Configuration -Environment "Development"
        if ($config) {
            Add-TestResult "Configuration Load" "PASS" "Configuration loaded successfully"
        } else {
            Add-TestResult "Configuration Load" "FAIL" "Configuration returned null"
        }
    }
    catch {
        Add-TestResult "Configuration Load" "FAIL" "Configuration load failed: $($_.Exception.Message)"
    }
    
    # Test 3: Authentication Test
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Authentication ---" -InformationAction Continue
    
    try {
        # Check if already authenticated
        $isAuthenticated = Test-GraphConnection
        
        if ($isAuthenticated) {
            Add-TestResult "Graph Connection" "PASS" "Already authenticated to Microsoft Graph"
        } else {
            Add-TestResult "Graph Connection" "WARNING" "Not authenticated - authentication required for full test"
            Write-Information "To run full test, authenticate first:" -InformationAction Continue
            Write-Information "  pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive" -InformationAction Continue
        }
    }
    catch {
        Add-TestResult "Graph Connection" "FAIL" "Authentication test failed: $($_.Exception.Message)"
    }
    
    # Test 4: Backup Function Test (if authenticated)
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Backup Functions ---" -InformationAction Continue
    
    # Test function availability
    $backupFunction = Get-Command "Backup-UserContacts" -ErrorAction SilentlyContinue
    if ($backupFunction) {
        Add-TestResult "Backup Function" "PASS" "Backup-UserContacts function is available"
    } else {
        Add-TestResult "Backup Function" "FAIL" "Backup-UserContacts function not found"
    }
    
    # Test helper functions
    $helperFunctions = @("Get-UserContactFolders", "Get-ContactsFromFolder", "Export-ContactsToVCard", "Export-ContactsToCSV")
    foreach ($funcName in $helperFunctions) {
        $func = Get-Command $funcName -ErrorAction SilentlyContinue
        if ($func) {
            Add-TestResult "Helper Function: $funcName" "PASS" "Function is available"
        } else {
            Add-TestResult "Helper Function: $funcName" "FAIL" "Function not found"
        }
    }
    
    # Test 5: Backup Directory Creation
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Backup Infrastructure ---" -InformationAction Continue
    
    try {
        $testBackupPath = Join-Path $scriptRoot "test" "backup-test"
        
        if (Test-Path $testBackupPath) {
            Remove-Item $testBackupPath -Recurse -Force
        }
        
        New-Item -Path $testBackupPath -ItemType Directory -Force | Out-Null
        
        if (Test-Path $testBackupPath) {
            Add-TestResult "Backup Directory" "PASS" "Test backup directory created successfully"
            
            # Cleanup
            Remove-Item $testBackupPath -Recurse -Force
        } else {
            Add-TestResult "Backup Directory" "FAIL" "Failed to create backup directory"
        }
    }
    catch {
        Add-TestResult "Backup Directory" "FAIL" "Directory creation failed: $($_.Exception.Message)"
    }
    
    # Test 6: Integration Test (if authenticated and user specified)
    if ((Test-GraphConnection) -and (-not [string]::IsNullOrEmpty($TestUserEmail))) {
        Write-Information "" -InformationAction Continue
        Write-Information "--- Running Integration Test ---" -InformationAction Continue
        Write-Information "⚠️  This will attempt to access Microsoft Graph" -InformationAction Continue
        
        try {
            $testBackupPath = Join-Path $scriptRoot "test" "integration-backup"
            
            # Create test backup
            $backupResult = Backup-UserContacts -UserEmail $TestUserEmail -BackupPath $testBackupPath -ContactFolder $TestFolder
            
            if ($backupResult.Success) {
                Add-TestResult "Integration Backup" "PASS" "Backup operation completed successfully"
                Add-TestResult "Integration Data" "PASS" "Backed up $($backupResult.ContactCount) contacts from $($backupResult.FolderCount) folders"
                
                # Verify backup files exist
                if (Test-Path $backupResult.BackupPath) {
                    $backupFiles = Get-ChildItem $backupResult.BackupPath -File
                    Add-TestResult "Backup Files" "PASS" "Created $($backupFiles.Count) backup files"
                } else {
                    Add-TestResult "Backup Files" "FAIL" "Backup directory not found"
                }
            } else {
                Add-TestResult "Integration Backup" "FAIL" "Backup operation failed: $($backupResult.Message)"
            }
        }
        catch {
            Add-TestResult "Integration Test" "FAIL" "Integration test failed: $($_.Exception.Message)"
        }
    } else {
        Add-TestResult "Integration Test" "SKIP" "Skipped - requires authentication and test user email"
    }
    
}
catch {
    Add-TestResult "Test Framework" "FAIL" "Test framework error: $($_.Exception.Message)"
}

# Test Summary
Write-Information "" -InformationAction Continue
Write-Information "=== Backup Operation Test Summary ===" -InformationAction Continue

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq "WARNING" }).Count
$skipCount = ($testResults | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Information "Tests Run: $($testResults.Count)" -InformationAction Continue
Write-Information "Passed: $passCount" -InformationAction Continue
Write-Information "Failed: $failCount" -InformationAction Continue
Write-Information "Warnings: $warnCount" -InformationAction Continue
Write-Information "Skipped: $skipCount" -InformationAction Continue
Write-Information "" -InformationAction Continue

foreach ($result in $testResults) {
    $statusIcon = switch ($result.Status) {
        "PASS" { "✅" }
        "FAIL" { "❌" }
        "WARNING" { "⚠️ " }
        "SKIP" { "⏭️ " }
    }
    Write-Information "$statusIcon $($result.Test): $($result.Message)" -InformationAction Continue
}

Write-Information "" -InformationAction Continue

if ($allTestsPassed -and $failCount -eq 0) {
    Write-Information "🎉 All backup operation tests passed!" -InformationAction Continue
    
    if ($warnCount -gt 0 -or $skipCount -gt 0) {
        Write-Information "" -InformationAction Continue
        Write-Information "Next steps for complete testing:" -InformationAction Continue
        if ($warnCount -gt 0) {
            Write-Information "1. Authenticate to Microsoft Graph: pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive" -InformationAction Continue
        }
        if ($skipCount -gt 0) {
            Write-Information "2. Run integration test: pwsh .\test\Test-BackupOperation.ps1 -TestUserEmail 'your@email.com'" -InformationAction Continue
        }
        Write-Information "3. Test with main script: pwsh .\Import-OutlookContact.ps1 -Mode Backup -UserEmail 'your@email.com'" -InformationAction Continue
    }
    
    exit 0
} else {
    Write-Error "❌ Some backup operation tests failed. Please review the issues above."
    exit 1
}
