<#
.SYNOPSIS
    Test-Prerequisites - Verify system prerequisites for Import-OutlookContact
    
.DESCRIPTION
    Tests all prerequisites required for Import-OutlookContact to function properly.
    Validates PowerShell version, modules, configuration, and environment setup.
    
.EXAMPLE
    pwsh .\scripts\Test-Prerequisites.ps1
    
.NOTES
    Version: 1.0.0
    Referenced in: README.md Installation section
#>

[CmdletBinding()]
param()

Write-Information "Testing Import-OutlookContact Prerequisites..." -InformationAction Continue

$testResults = @()
$allTestsPassed = $true

# Test 1: PowerShell Version
Write-Information "Checking PowerShell version..." -InformationAction Continue
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $testResults += @{ Test = "PowerShell Version"; Status = "PASS"; Message = "PowerShell $($PSVersionTable.PSVersion) detected" }
    Write-Information "✅ PowerShell version: $($PSVersionTable.PSVersion)" -InformationAction Continue
}
else {
    $testResults += @{ Test = "PowerShell Version"; Status = "FAIL"; Message = "PowerShell 7.0+ required, found $($PSVersionTable.PSVersion)" }
    Write-Warning "❌ PowerShell version: $($PSVersionTable.PSVersion) (7.0+ required)"
    $allTestsPassed = $false
}

# Test 2: Configuration Files
Write-Information "Checking configuration files..." -InformationAction Continue
$configPath = Join-Path $PSScriptRoot ".." "config" "appsettings.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        $testResults += @{ Test = "Configuration File"; Status = "PASS"; Message = "Configuration loaded successfully" }
        Write-Information "✅ Configuration file: Found and valid" -InformationAction Continue
    }
    catch {
        $testResults += @{ Test = "Configuration File"; Status = "FAIL"; Message = "Configuration file invalid: $($_.Exception.Message)" }
        Write-Warning "❌ Configuration file: Invalid JSON format"
        $allTestsPassed = $false
    }
}
else {
    $testResults += @{ Test = "Configuration File"; Status = "FAIL"; Message = "Configuration file not found: $configPath" }
    Write-Warning "❌ Configuration file: Not found at $configPath"
    $allTestsPassed = $false
}

# Test 3: Microsoft Graph Module
Write-Information "Checking Microsoft Graph module..." -InformationAction Continue
$graphModule = Get-Module -ListAvailable -Name "Microsoft.Graph"
if ($graphModule) {
    $testResults += @{ Test = "Microsoft.Graph Module"; Status = "PASS"; Message = "Version $($graphModule[0].Version) available" }
    Write-Information "✅ Microsoft.Graph module: Version $($graphModule[0].Version)" -InformationAction Continue
}
else {
    $testResults += @{ Test = "Microsoft.Graph Module"; Status = "FAIL"; Message = "Module not installed" }
    Write-Warning "❌ Microsoft.Graph module: Not installed"
    Write-Information "   Install with: Install-Module Microsoft.Graph -Scope CurrentUser" -InformationAction Continue
    $allTestsPassed = $false
}

# Test 4: Universal Dashboard Module (Optional)
Write-Information "Checking Universal Dashboard module..." -InformationAction Continue
$udModule = Get-Module -ListAvailable -Name "UniversalDashboard*"
if ($udModule) {
    $testResults += @{ Test = "UniversalDashboard Module"; Status = "PASS"; Message = "Version $($udModule[0].Version) available" }
    Write-Information "✅ UniversalDashboard module: Version $($udModule[0].Version)" -InformationAction Continue
}
else {
    $testResults += @{ Test = "UniversalDashboard Module"; Status = "WARNING"; Message = "Module not installed (web interface unavailable)" }
    Write-Warning "⚠️  UniversalDashboard module: Not installed (web interface will be unavailable)"
    Write-Information "   Install with: Install-Module UniversalDashboard.Community -Scope CurrentUser" -InformationAction Continue
}

# Test 5: Main Application Script
Write-Information "Checking main application script..." -InformationAction Continue
$mainScriptPath = Join-Path $PSScriptRoot ".." "Import-OutlookContact.ps1"
if (Test-Path $mainScriptPath) {
    $testResults += @{ Test = "Main Script"; Status = "PASS"; Message = "Import-OutlookContact.ps1 found" }
    Write-Information "✅ Main script: Found at $mainScriptPath" -InformationAction Continue
}
else {
    $testResults += @{ Test = "Main Script"; Status = "FAIL"; Message = "Import-OutlookContact.ps1 not found" }
    Write-Warning "❌ Main script: Not found at $mainScriptPath"
    $allTestsPassed = $false
}

# Test 6: Service Starter Script
Write-Information "Checking service starter script..." -InformationAction Continue
$serviceScriptPath = Join-Path $PSScriptRoot ".." "Start-ImportOutlookContact.ps1"
if (Test-Path $serviceScriptPath) {
    $testResults += @{ Test = "Service Script"; Status = "PASS"; Message = "Start-ImportOutlookContact.ps1 found" }
    Write-Information "✅ Service script: Found at $serviceScriptPath" -InformationAction Continue
}
else {
    $testResults += @{ Test = "Service Script"; Status = "FAIL"; Message = "Start-ImportOutlookContact.ps1 not found" }
    Write-Warning "❌ Service script: Not found at $serviceScriptPath"
    $allTestsPassed = $false
}

# Test 7: Directory Structure
Write-Information "Checking directory structure..." -InformationAction Continue
$requiredDirs = @("config", "modules", "scripts", "docs", "templates")
$missingDirs = @()

foreach ($dir in $requiredDirs) {
    $dirPath = Join-Path $PSScriptRoot ".." $dir
    if (-not (Test-Path $dirPath)) {
        $missingDirs += $dir
    }
}

if ($missingDirs.Count -eq 0) {
    $testResults += @{ Test = "Directory Structure"; Status = "PASS"; Message = "All required directories present" }
    Write-Information "✅ Directory structure: Complete" -InformationAction Continue
}
else {
    $testResults += @{ Test = "Directory Structure"; Status = "FAIL"; Message = "Missing directories: $($missingDirs -join ', ')" }
    Write-Warning "❌ Directory structure: Missing directories: $($missingDirs -join ', ')"
    $allTestsPassed = $false
}

# Summary
Write-Information "" -InformationAction Continue
Write-Information "=== Prerequisites Test Summary ===" -InformationAction Continue

foreach ($result in $testResults) {
    $statusIcon = switch ($result.Status) {
        "PASS" { "✅" }
        "FAIL" { "❌" }
        "WARNING" { "⚠️ " }
    }
    Write-Information "$statusIcon $($result.Test): $($result.Message)" -InformationAction Continue
}

Write-Information "" -InformationAction Continue

if ($allTestsPassed) {
    Write-Information "🎉 All critical prerequisites met! Import-OutlookContact is ready to use." -InformationAction Continue
    Write-Information "" -InformationAction Continue
    Write-Information "Next steps:" -InformationAction Continue
    Write-Information "1. Configure Azure AD app registration" -InformationAction Continue
    Write-Information "2. Set environment variables (AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET)" -InformationAction Continue
    Write-Information "3. Run: pwsh .\Start-ImportOutlookContact.ps1 -Mode Development" -InformationAction Continue
    exit 0
}
else {
    Write-Error "❌ Some prerequisites are not met. Please address the issues above before proceeding."
    exit 1
}
