<#
.SYNOPSIS
    Setup-Environment - Configure environment variables for Import-OutlookContact
    
.DESCRIPTION
    Sets up required environment variables for Azure AD authentication.
    Provides interactive prompts for secure credential entry.
    
.PARAMETER TenantId
    Azure AD Tenant ID
    
.PARAMETER ClientId
    Azure AD Application (Client) ID
    
.PARAMETER ClientSecret
    Azure AD Application Client Secret (optional)
    
.PARAMETER Interactive
    Use interactive prompts for credential entry
    
.EXAMPLE
    pwsh .\scripts\Setup-Environment.ps1 -Interactive
    
.EXAMPLE
    pwsh .\scripts\Setup-Environment.ps1 -TenantId "your-tenant-id" -ClientId "your-client-id"
    
.NOTES
    Version: 1.0.0
    Sets environment variables for current PowerShell session and optionally persists them
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientId,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory = $false)]
    [switch]$Interactive
)

Write-Information "=== Import-OutlookContact Environment Setup ===" -InformationAction Continue
Write-Information "" -InformationAction Continue

# Function to securely prompt for input
function Get-SecureInput {
    param(
        [string]$Prompt,
        [bool]$IsSecret = $false,
        [string]$DefaultValue = ""
    )
    
    if ($IsSecret) {
        $secureInput = Read-Host -Prompt $Prompt -AsSecureString
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureInput)
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        return $plainText
    }
    else {
        $userInput = Read-Host -Prompt "$Prompt $(if($DefaultValue) {"(current: $DefaultValue)"})"
        if ([string]::IsNullOrEmpty($userInput) -and $DefaultValue) { 
            return $DefaultValue 
        }
        else { 
            return $userInput 
        }
    }
}

try {
    # Check current environment variables
    $currentTenantId = [Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
    $currentClientId = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
    $currentClientSecret = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
    
    Write-Information "Current environment variables:" -InformationAction Continue
    Write-Information "  AZURE_TENANT_ID: $(if($currentTenantId) { "Set (length: $($currentTenantId.Length))" } else { "Not set" })" -InformationAction Continue
    Write-Information "  AZURE_CLIENT_ID: $(if($currentClientId) { "Set (length: $($currentClientId.Length))" } else { "Not set" })" -InformationAction Continue
    Write-Information "  AZURE_CLIENT_SECRET: $(if($currentClientSecret) { "Set (length: $($currentClientSecret.Length))" } else { "Not set" })" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    
    # Interactive mode
    if ($Interactive) {
        Write-Information "=== Interactive Environment Variable Setup ===" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        Write-Information "Please provide your Azure AD application details:" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        
        # Get Tenant ID
        if ([string]::IsNullOrEmpty($TenantId)) {
            Write-Information "Azure AD Tenant ID (found in Azure Portal > Azure Active Directory > Properties)" -InformationAction Continue
            $TenantId = Get-SecureInput -Prompt "Enter Tenant ID" -DefaultValue $currentTenantId
        }
        
        # Get Client ID
        if ([string]::IsNullOrEmpty($ClientId)) {
            Write-Information "" -InformationAction Continue
            Write-Information "Azure AD Application (Client) ID (found in your App Registration)" -InformationAction Continue
            $ClientId = Get-SecureInput -Prompt "Enter Client ID" -DefaultValue $currentClientId
        }
        
        # Get Client Secret (optional)
        if ([string]::IsNullOrEmpty($ClientSecret)) {
            Write-Information "" -InformationAction Continue
            Write-Information "Azure AD Client Secret (optional - leave empty for interactive authentication)" -InformationAction Continue
            $ClientSecret = Get-SecureInput -Prompt "Enter Client Secret (optional)" -IsSecret $true
        }
    }
    
    # Validate required values
    if ([string]::IsNullOrEmpty($TenantId)) {
        Write-Error "Tenant ID is required. Use -TenantId parameter or -Interactive switch."
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($ClientId)) {
        Write-Error "Client ID is required. Use -ClientId parameter or -Interactive switch."
        exit 1
    }
    
    # Set environment variables for current session
    Write-Information "Setting environment variables for current PowerShell session..." -InformationAction Continue
    
    [Environment]::SetEnvironmentVariable("AZURE_TENANT_ID", $TenantId, "Process")
    [Environment]::SetEnvironmentVariable("AZURE_CLIENT_ID", $ClientId, "Process")
    
    if (-not [string]::IsNullOrEmpty($ClientSecret)) {
        [Environment]::SetEnvironmentVariable("AZURE_CLIENT_SECRET", $ClientSecret, "Process")
    }
    
    # Verify variables are set
    Write-Information "" -InformationAction Continue
    Write-Information "=== Verification ===" -InformationAction Continue
    
    $verifyTenantId = [Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
    $verifyClientId = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
    $verifyClientSecret = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
    
    if ($verifyTenantId) {
        Write-Information "✅ AZURE_TENANT_ID set successfully (length: $($verifyTenantId.Length))" -InformationAction Continue
    }
    else {
        Write-Error "❌ Failed to set AZURE_TENANT_ID"
    }
    
    if ($verifyClientId) {
        Write-Information "✅ AZURE_CLIENT_ID set successfully (length: $($verifyClientId.Length))" -InformationAction Continue
    }
    else {
        Write-Error "❌ Failed to set AZURE_CLIENT_ID"
    }
    
    if ($verifyClientSecret) {
        Write-Information "✅ AZURE_CLIENT_SECRET set successfully (length: $($verifyClientSecret.Length))" -InformationAction Continue
    }
    else {
        Write-Information "⚠️  AZURE_CLIENT_SECRET not set (interactive auth will be used)" -InformationAction Continue
    }
    
    Write-Information "" -InformationAction Continue
    Write-Information "🎉 Environment variables configured successfully!" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    Write-Information "Next steps:" -InformationAction Continue
    Write-Information "1. Test configuration: pwsh .\scripts\Test-Authentication.ps1 -TestMode Configuration" -InformationAction Continue
    Write-Information "2. Test authentication: pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive" -InformationAction Continue
    Write-Information "3. Run main application: pwsh .\Import-OutlookContact.ps1 -Mode Backup -UserEmail 'test@example.com'" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    Write-Information "Note: These variables are set for this PowerShell session only." -InformationAction Continue
    Write-Information "To persist them, add them to your PowerShell profile or use system environment variables." -InformationAction Continue
    
}
catch {
    Write-Error "Environment setup failed: $($_.Exception.Message)"
    exit 1
}
