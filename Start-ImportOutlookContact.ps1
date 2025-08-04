<#
.SYNOPSIS
    Start-ImportOutlookContact - Service starter and management script
    
.DESCRIPTION
    Service management script for Import-OutlookContact application.
    Supports multiple deployment modes: Development, Production, Service.
    
.PARAMETER Mode
    Deployment mode: Development, Production, Service
    
.PARAMETER Port
    Port number for web interface (default: 8080)
    
.PARAMETER LogLevel
    Logging level: Debug, Information, Warning, Error (default: Information)
    
.PARAMETER ConfigPath
    Custom configuration file path
    
.EXAMPLE
    pwsh .\Start-ImportOutlookContact.ps1 -Mode Development -Port 5000 -LogLevel Debug
    
.EXAMPLE
    pwsh .\Start-ImportOutlookContact.ps1 -Mode Production
    
.EXAMPLE
    pwsh .\Start-ImportOutlookContact.ps1 -Mode Service
    
.NOTES
    Version: 1.0.0
    Author: Import-OutlookContact Team
    Requires: PowerShell 7.0+, UniversalDashboard module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Development", "Production", "Service")]
    [string]$Mode = "Development",
    
    [Parameter(Mandatory = $false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Information", "Warning", "Error")]
    [string]$LogLevel = "Information",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

# Script metadata
$script:ApplicationInfo = @{
    Name    = "Import-OutlookContact Service"
    Version = "1.0.0"
    Author  = "Import-OutlookContact Team"
}

# Initialize logging
$script:StartTime = Get-Date
Write-Information "$($script:ApplicationInfo.Name) v$($script:ApplicationInfo.Version)" -InformationAction Continue
Write-Information "Starting in $Mode mode on port $Port" -InformationAction Continue

# Load configuration
try {
    Write-Verbose "Loading application configuration..."
    
    # Determine configuration file path
    if ([string]::IsNullOrEmpty($ConfigPath)) {
        $configPath = Join-Path $PSScriptRoot "config" "appsettings.json"
    }
    else {
        $configPath = $ConfigPath
    }
    
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }
    
    $script:Config = Get-Content $configPath | ConvertFrom-Json
    
    # Override environment in config
    $script:Config.Application.Environment = $Mode
    
    # Load environment-specific overrides
    $envConfigPath = Join-Path $PSScriptRoot "config" "appsettings.$($Mode.ToLower()).json"
    if (Test-Path $envConfigPath) {
        # $envConfig = Get-Content $envConfigPath | ConvertFrom-Json
        Write-Verbose "Environment configuration found: $Mode (merge not yet implemented)"
        # TODO: Merge environment configuration
    }
    
    Write-Information "Configuration loaded successfully" -InformationAction Continue
    
}
catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Import required modules
try {
    Write-Information "Importing required modules..." -InformationAction Continue
    
    # Check for Universal Dashboard (for web interface)
    if (Get-Module -ListAvailable -Name "UniversalDashboard*") {
        $udModule = Get-Module -ListAvailable -Name "UniversalDashboard*" | Sort-Object Version -Descending | Select-Object -First 1
        Import-Module $udModule.Name -Force -Verbose:$false
        Write-Verbose "Universal Dashboard module imported: $($udModule.Name)"
        $script:WebInterfaceAvailable = $true
    }
    else {
        Write-Warning "Universal Dashboard module not found. Web interface will not be available."
        Write-Information "Install with: Install-Module UniversalDashboard.Community -Scope CurrentUser" -InformationAction Continue
        $script:WebInterfaceAvailable = $false
    }
    
    # Import Microsoft Graph
    if (Get-Module -ListAvailable -Name "Microsoft.Graph") {
        Import-Module Microsoft.Graph -Force -Verbose:$false
        Write-Verbose "Microsoft.Graph module imported"
    }
    else {
        Write-Warning "Microsoft.Graph module not found. Core functionality will be limited."
        Write-Information "Install with: Install-Module Microsoft.Graph -Scope CurrentUser" -InformationAction Continue
    }
    
}
catch {
    Write-Error "Failed to import modules: $($_.Exception.Message)"
    exit 1
}

# Initialize service functions
function Start-WebInterface {
    [CmdletBinding()]
    param(
        [int]$Port,
        [string]$Mode
    )
    
    if (-not $script:WebInterfaceAvailable) {
        Write-Warning "Web interface not available - UniversalDashboard module not found"
        return
    }
    
    try {
        Write-Information "Starting web interface on port $Port..." -InformationAction Continue
        
        # TODO: Implement Universal Dashboard web interface
        # This is a placeholder for the actual web interface implementation
        Write-Information "Web interface would start here (not yet implemented)" -InformationAction Continue
        Write-Information "Web interface would be available at: http://localhost:$Port" -InformationAction Continue
        
        # For now, just keep the script running
        Write-Information "Press Ctrl+C to stop the service" -InformationAction Continue
        
        # Service loop (placeholder)
        while ($true) {
            Start-Sleep -Seconds 30
            Write-Verbose "Service heartbeat - $(Get-Date)"
        }
        
    }
    catch {
        Write-Error "Failed to start web interface: $($_.Exception.Message)"
        throw
    }
}

function Start-ConsoleMode {
    [CmdletBinding()]
    param()
    
    Write-Information "Starting in console mode..." -InformationAction Continue
    Write-Information "Import-OutlookContact is ready for CLI operations" -InformationAction Continue
    Write-Information "Use: pwsh .\Import-OutlookContact.ps1 -Mode <operation> -UserEmail <email>" -InformationAction Continue
    
    # Show available operations
    Write-Information "" -InformationAction Continue
    Write-Information "Available operations:" -InformationAction Continue
    Write-Information "  BulkAdd    - Import contacts from CSV/vCard" -InformationAction Continue
    Write-Information "  OnboardUser - Onboard new user with contacts" -InformationAction Continue
    Write-Information "  Edit       - Edit existing contacts" -InformationAction Continue
    Write-Information "  Backup     - Backup user contacts" -InformationAction Continue
    Write-Information "  Restore    - Restore from backup" -InformationAction Continue
    Write-Information "  Merge      - Merge duplicate contacts" -InformationAction Continue
    Write-Information "" -InformationAction Continue
}

function Test-Prerequisites {
    [CmdletBinding()]
    param()
    
    $prerequisites = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $prerequisites += "PowerShell 7.0+ is required (current: $($PSVersionTable.PSVersion))"
    }
    
    # Check required modules
    if (-not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
        $prerequisites += "Microsoft.Graph module is required"
    }
    
    # Check configuration
    $configPath = Join-Path $PSScriptRoot "config" "appsettings.json"
    if (-not (Test-Path $configPath)) {
        $prerequisites += "Configuration file missing: $configPath"
    }
    
    # Check environment variables for production
    if ($Mode -eq "Production") {
        $requiredEnvVars = @("AZURE_TENANT_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET")
        foreach ($envVar in $requiredEnvVars) {
            if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($envVar))) {
                $prerequisites += "Environment variable missing: $envVar"
            }
        }
    }
    
    if ($prerequisites.Count -gt 0) {
        Write-Error "Prerequisites not met:"
        foreach ($prereq in $prerequisites) {
            Write-Error "  - $prereq"
        }
        return $false
    }
    
    Write-Information "All prerequisites met" -InformationAction Continue
    return $true
}

# Main service startup logic
try {
    Write-Information "Checking prerequisites..." -InformationAction Continue
    
    if (-not (Test-Prerequisites)) {
        Write-Error "Cannot start service - prerequisites not met"
        exit 1
    }
    
    # Set logging level
    $VerbosePreference = if ($LogLevel -eq "Debug") { "Continue" } else { "SilentlyContinue" }
    $InformationPreference = if ($LogLevel -in @("Debug", "Information")) { "Continue" } else { "SilentlyContinue" }
    
    Write-Information "Prerequisites check passed" -InformationAction Continue
    Write-Information "Configuration: $($script:Config.Application.Name) v$($script:Config.Application.Version)" -InformationAction Continue
    
    # Start appropriate mode
    switch ($Mode) {
        "Development" {
            Write-Information "Starting in Development mode..." -InformationAction Continue
            if ($script:WebInterfaceAvailable) {
                Start-WebInterface -Port $Port -Mode $Mode
            }
            else {
                Start-ConsoleMode
            }
        }
        "Production" {
            Write-Information "Starting in Production mode..." -InformationAction Continue
            Start-WebInterface -Port $Port -Mode $Mode
        }
        "Service" {
            Write-Information "Starting in Service mode..." -InformationAction Continue
            # Service mode runs as a background service
            Start-WebInterface -Port $Port -Mode $Mode
        }
    }
    
}
catch {
    Write-Error "Failed to start Import-OutlookContact service: $($_.Exception.Message)"
    exit 1
}
