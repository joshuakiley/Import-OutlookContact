<#
.SYNOPSIS
    Test-Authentication - Test Microsoft Graph authentication functionality
    
.DESCRIPTION
    Tests the authentication module functionality including configuration loading,
    Azure AD connectivity, and permission validation.
    
.PARAMETER TestMode
    Test mode: Configuration, Connection, Interactive, ServicePrincipal
    
.EXAMPLE
    pwsh .\scripts\Test-Authentication.ps1 -TestMode Configuration
    
.EXAMPLE
    pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive
    
.NOTES
    Version: 1.0.0
    Tests authentication functionality from /modules/Authentication.psm1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Configuration", "Connection", "Interactive", "ServicePrincipal", "All")]
    [string]$TestMode = "Configuration"
)

Write-Information "Testing Import-OutlookContact Authentication Module..." -InformationAction Continue
Write-Information "Test Mode: $TestMode" -InformationAction Continue
Write-Information "" -InformationAction Continue

$testResults = @()
$allTestsPassed = $true

# Helper function to add test results
function Add-TestResult {
    param($TestName, $Status, $Message, $Details = @{})
    
    $script:testResults += @{
        Test    = $TestName
        Status  = $Status
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
    # Import required modules
    Write-Verbose "Importing authentication modules..."
    
    $configModulePath = Join-Path $PSScriptRoot ".." "modules" "Configuration.psm1"
    $authModulePath = Join-Path $PSScriptRoot ".." "modules" "Authentication.psm1"
    
    if (-not (Test-Path $configModulePath)) {
        Add-TestResult "Module Import" "FAIL" "Configuration module not found: $configModulePath"
        exit 1
    }
    
    if (-not (Test-Path $authModulePath)) {
        Add-TestResult "Module Import" "FAIL" "Authentication module not found: $authModulePath"
        exit 1
    }
    
    Import-Module $configModulePath -Force -Verbose:$false
    Import-Module $authModulePath -Force -Verbose:$false
    
    Add-TestResult "Module Import" "PASS" "Authentication modules imported successfully"
    
    # Test 1: Configuration Loading
    if ($TestMode -in @("Configuration", "All")) {
        Write-Information "" -InformationAction Continue
        Write-Information "--- Testing Configuration Loading ---" -InformationAction Continue
        
        try {
            $config = Initialize-Configuration -Environment "Development"
            if ($config) {
                Add-TestResult "Configuration Load" "PASS" "Configuration loaded successfully"
            }
            else {
                Add-TestResult "Configuration Load" "FAIL" "Configuration returned null"
            }
        }
        catch {
            Add-TestResult "Configuration Load" "FAIL" "Failed to load configuration: $($_.Exception.Message)"
        }
        
        # Test Azure AD configuration
        try {
            $azureConfig = Get-AzureADConfiguration
            if ($azureConfig -and $azureConfig.TenantId -and $azureConfig.ClientId) {
                Add-TestResult "Azure AD Config" "PASS" "Azure AD configuration valid"
            }
            else {
                Add-TestResult "Azure AD Config" "FAIL" "Azure AD configuration incomplete"
            }
        }
        catch {
            Add-TestResult "Azure AD Config" "FAIL" "Azure AD configuration error: $($_.Exception.Message)"
        }
        
        # Test configuration values
        try {
            $tenantId = Get-ConfigurationValue -Path "AzureAD.TenantId"
            $clientId = Get-ConfigurationValue -Path "AzureAD.ClientId"
            $redirectUri = Get-ConfigurationValue -Path "AzureAD.RedirectUri"
            
            if ($tenantId -and $clientId -and $redirectUri) {
                Add-TestResult "Config Values" "PASS" "All required configuration values present"
            }
            else {
                Add-TestResult "Config Values" "FAIL" "Missing required configuration values"
            }
        }
        catch {
            Add-TestResult "Config Values" "FAIL" "Configuration value retrieval failed: $($_.Exception.Message)"
        }
    }
    
    # Test 2: Connection Test (without authentication)
    if ($TestMode -in @("Connection", "All")) {
        Write-Information "" -InformationAction Continue
        Write-Information "--- Testing Connection Logic ---" -InformationAction Continue
        
        # Test connection status (should be false initially)
        $connectionStatus = Test-GraphConnection
        if ($connectionStatus -eq $false) {
            Add-TestResult "Connection Status" "PASS" "No existing connection detected (expected)"
        }
        else {
            Add-TestResult "Connection Status" "WARNING" "Unexpected existing connection detected"
        }
        
        # Test authentication context retrieval
        $authContext = Get-AuthenticationContext
        if ($authContext -eq $null) {
            Add-TestResult "Auth Context" "PASS" "No authentication context (expected)"
        }
        else {
            Add-TestResult "Auth Context" "WARNING" "Unexpected authentication context found"
        }
    }
    
    # Test 3: Interactive Authentication (if requested)
    if ($TestMode -in @("Interactive")) {
        Write-Information "" -InformationAction Continue
        Write-Information "--- Testing Interactive Authentication ---" -InformationAction Continue
        Write-Information "This will require user interaction..." -InformationAction Continue
        
        try {
            # Initialize configuration if not already done
            if (-not $config) {
                $config = Initialize-Configuration -Environment "Development"
            }
            
            $azureConfig = Get-AzureADConfiguration
            
            $authResult = Initialize-GraphAuthentication -TenantId $azureConfig.TenantId -ClientId $azureConfig.ClientId -AuthenticationMethod Interactive
            
            if ($authResult) {
                Add-TestResult "Interactive Auth" "PASS" "Interactive authentication successful"
                
                # Test connection after authentication
                if (Test-GraphConnection) {
                    Add-TestResult "Post-Auth Connection" "PASS" "Connection test successful after authentication"
                }
                else {
                    Add-TestResult "Post-Auth Connection" "FAIL" "Connection test failed after authentication"
                }
                
                # Test permission validation
                $requiredScopes = @("User.Read")
                if (Test-RequiredPermissions -RequiredScopes $requiredScopes) {
                    Add-TestResult "Permission Test" "PASS" "Required permissions validated"
                }
                else {
                    Add-TestResult "Permission Test" "FAIL" "Permission validation failed"
                }
                
            }
            else {
                Add-TestResult "Interactive Auth" "FAIL" "Interactive authentication failed"
            }
        }
        catch {
            Add-TestResult "Interactive Auth" "FAIL" "Interactive authentication error: $($_.Exception.Message)"
        }
    }
    
    # Test 4: Service Principal Authentication (if credentials available)
    if ($TestMode -in @("ServicePrincipal")) {
        Write-Information "" -InformationAction Continue
        Write-Information "--- Testing Service Principal Authentication ---" -InformationAction Continue
        
        try {
            # Initialize configuration if not already done
            if (-not $config) {
                $config = Initialize-Configuration -Environment "Development"
            }
            
            $azureConfig = Get-AzureADConfiguration
            $clientSecret = Get-SecureClientSecret
            
            if ($clientSecret) {
                $authResult = Initialize-GraphAuthentication -TenantId $azureConfig.TenantId -ClientId $azureConfig.ClientId -ClientSecret $clientSecret -AuthenticationMethod ServicePrincipal
                
                if ($authResult) {
                    Add-TestResult "Service Principal Auth" "PASS" "Service principal authentication successful"
                }
                else {
                    Add-TestResult "Service Principal Auth" "FAIL" "Service principal authentication failed"
                }
            }
            else {
                Add-TestResult "Service Principal Auth" "SKIP" "No client secret available for testing"
            }
        }
        catch {
            Add-TestResult "Service Principal Auth" "FAIL" "Service principal authentication error: $($_.Exception.Message)"
        }
    }
    
}
catch {
    Add-TestResult "Test Framework" "FAIL" "Test framework error: $($_.Exception.Message)"
}
finally {
    # Cleanup
    try {
        if (Get-MgContext) {
            Write-Verbose "Cleaning up authentication context..."
            Disconnect-GraphAuthentication
        }
    }
    catch {
        Write-Warning "Cleanup error: $($_.Exception.Message)"
    }
}

# Summary
Write-Information "" -InformationAction Continue
Write-Information "=== Authentication Test Summary ===" -InformationAction Continue

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

if ($allTestsPassed) {
    Write-Information "🎉 All authentication tests passed!" -InformationAction Continue
    
    if ($TestMode -eq "Configuration") {
        Write-Information "" -InformationAction Continue
        Write-Information "Next steps to test authentication:" -InformationAction Continue
        Write-Information "1. Set environment variables: AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET" -InformationAction Continue
        Write-Information "2. Run: pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive" -InformationAction Continue
        Write-Information "3. Or test with main script: pwsh .\Import-OutlookContact.ps1 -Mode Backup -UserEmail 'test@example.com'" -InformationAction Continue
    }
    
    exit 0
}
else {
    Write-Error "❌ Some authentication tests failed. Please review the issues above."
    exit 1
}
