<#
.SYNOPSIS
    Configuration management module for Import-OutlookContact
    
.DESCRIPTION
    Handles application configuration loading, environment variable management,
    and secure credential storage for Import-OutlookContact application.
    
.NOTES
    Version: 1.0.0
    Author: Import-OutlookContact Team
    Referenced in: /docs/Deploy.md Configuration Management section
#>

# Module variables
$script:AppConfig = $null
$script:ConfigPath = $null

<#
.SYNOPSIS
    Load application configuration
    
.DESCRIPTION
    Loads configuration from appsettings.json and environment-specific overrides.
    Supports environment variable substitution for secure values.
    
.PARAMETER ConfigurationPath
    Path to the main configuration file (default: config/appsettings.json)
    
.PARAMETER Environment
    Environment name for loading specific overrides (Development, Production, etc.)
    
.EXAMPLE
    Initialize-Configuration -Environment "Development"
    
.EXAMPLE
    Initialize-Configuration -ConfigurationPath ".\custom-config.json" -Environment "Production"
#>
function Initialize-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath,
        
        [Parameter(Mandatory = $false)]
        [string]$Environment = "Development"
    )
    
    try {
        Write-Verbose "Initializing configuration..."
        
        # Determine configuration file path
        if ([string]::IsNullOrEmpty($ConfigurationPath)) {
            $script:ConfigPath = Join-Path $PSScriptRoot ".." "config" "appsettings.json"
        }
        else {
            $script:ConfigPath = $ConfigurationPath
        }
        
        if (-not (Test-Path $script:ConfigPath)) {
            throw "Configuration file not found: $script:ConfigPath"
        }
        
        # Load base configuration
        Write-Verbose "Loading base configuration from: $script:ConfigPath"
        $baseConfig = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json -AsHashtable
        
        # Load environment-specific overrides
        $envConfigPath = Join-Path (Split-Path $script:ConfigPath) "appsettings.$($Environment.ToLower()).json"
        if (Test-Path $envConfigPath) {
            Write-Verbose "Loading environment configuration from: $envConfigPath"
            $envConfig = Get-Content $envConfigPath -Raw | ConvertFrom-Json -AsHashtable
            
            # Merge environment configuration into base configuration
            $script:AppConfig = Merge-Configuration -BaseConfig $baseConfig -OverrideConfig $envConfig
        }
        else {
            Write-Verbose "No environment-specific configuration found for: $Environment"
            $script:AppConfig = $baseConfig
        }
        
        # Update environment in config
        if ($script:AppConfig.ContainsKey("Application")) {
            $script:AppConfig.Application.Environment = $Environment
        }
        
        # Substitute environment variables
        $script:AppConfig = Expand-EnvironmentVariables -Configuration $script:AppConfig
        
        Write-Information "✅ Configuration loaded successfully" -InformationAction Continue
        Write-Verbose "Environment: $Environment"
        Write-Verbose "Configuration sections: $($script:AppConfig.Keys -join ', ')"
        
        return $script:AppConfig
        
    }
    catch {
        Write-Error "Failed to initialize configuration: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Get configuration value
    
.DESCRIPTION
    Retrieves a configuration value using dot notation path (e.g., "AzureAD.TenantId").
    
.PARAMETER Path
    Configuration path using dot notation
    
.PARAMETER DefaultValue
    Default value if configuration path is not found
    
.EXAMPLE
    Get-ConfigurationValue -Path "AzureAD.TenantId"
    
.EXAMPLE
    Get-ConfigurationValue -Path "Features.AutoBackup" -DefaultValue $true
#>
function Get-ConfigurationValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [object]$DefaultValue = $null
    )
    
    try {
        if (-not $script:AppConfig) {
            Write-Warning "Configuration not initialized. Call Initialize-Configuration first."
            return $DefaultValue
        }
        
        # Split path into components
        $pathComponents = $Path.Split('.')
        $current = $script:AppConfig
        
        # Navigate through the configuration path
        foreach ($component in $pathComponents) {
            if ($current -is [hashtable] -and $current.ContainsKey($component)) {
                $current = $current[$component]
            }
            elseif ($current -is [PSCustomObject] -and $current.PSObject.Properties.Name -contains $component) {
                $current = $current.$component
            }
            else {
                Write-Verbose "Configuration path not found: $Path"
                return $DefaultValue
            }
        }
        
        return $current
        
    }
    catch {
        Write-Warning "Error retrieving configuration value '$Path': $($_.Exception.Message)"
        return $DefaultValue
    }
}

<#
.SYNOPSIS
    Get Azure AD configuration
    
.DESCRIPTION
    Retrieves Azure AD configuration settings with environment variable substitution
    and validation.
    
.EXAMPLE
    Get-AzureADConfiguration
#>
function Get-AzureADConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        if (-not $script:AppConfig) {
            throw "Configuration not initialized. Call Initialize-Configuration first."
        }
        
        # Get Azure AD configuration section
        $azureConfig = Get-ConfigurationValue -Path "AzureAD"
        if (-not $azureConfig) {
            throw "AzureAD configuration section not found"
        }
        
        # Validate required settings
        $requiredSettings = @("TenantId", "ClientId", "RedirectUri")
        $missingSettings = @()
        
        foreach ($setting in $requiredSettings) {
            if (-not $azureConfig.$setting -or [string]::IsNullOrWhiteSpace($azureConfig.$setting)) {
                $missingSettings += $setting
            }
        }
        
        if ($missingSettings.Count -gt 0) {
            throw "Missing required Azure AD configuration: $($missingSettings -join ', ')"
        }
        
        # Return configuration with additional metadata
        return @{
            TenantId     = $azureConfig.TenantId
            ClientId     = $azureConfig.ClientId
            ClientSecret = $azureConfig.ClientSecret  # May be null for interactive auth
            RedirectUri  = $azureConfig.RedirectUri
            Authority    = "https://login.microsoftonline.com/$($azureConfig.TenantId)"
            Validated    = $true
            LoadedAt     = Get-Date
        }
        
    }
    catch {
        Write-Error "Failed to get Azure AD configuration: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Get secure client secret from environment or configuration
    
.DESCRIPTION
    Retrieves Azure AD client secret from environment variables or configuration,
    returning it as a SecureString for enhanced security.
    
.EXAMPLE
    Get-SecureClientSecret
#>
function Get-SecureClientSecret {
    [CmdletBinding()]
    param()
    
    try {
        # Try environment variable first (most secure)
        $clientSecret = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
        
        if ([string]::IsNullOrEmpty($clientSecret)) {
            # Fall back to configuration (less secure)
            $clientSecret = Get-ConfigurationValue -Path "AzureAD.ClientSecret"
        }
        
        # Check if the value is an unexpanded environment variable placeholder
        if ([string]::IsNullOrEmpty($clientSecret) -or $clientSecret -match '^\$\{[^}]+\}$') {
            Write-Verbose "No client secret found - interactive authentication will be used"
            return $null
        }
        
        # Convert to SecureString
        $secureSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
        
        # Clear the plain text variable
        $clientSecret = $null
        
        return $secureSecret
        
    }
    catch {
        Write-Error "Failed to retrieve client secret: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Merge configuration objects
    
.DESCRIPTION
    Internal function to merge environment-specific configuration overrides
    into the base configuration.
    
.PARAMETER BaseConfig
    Base configuration hashtable
    
.PARAMETER OverrideConfig
    Override configuration hashtable
#>
function Merge-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BaseConfig,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$OverrideConfig
    )
    
    $merged = $BaseConfig.Clone()
    
    foreach ($key in $OverrideConfig.Keys) {
        if ($merged.ContainsKey($key) -and $merged[$key] -is [hashtable] -and $OverrideConfig[$key] -is [hashtable]) {
            # Recursively merge nested hashtables
            $merged[$key] = Merge-Configuration -BaseConfig $merged[$key] -OverrideConfig $OverrideConfig[$key]
        }
        else {
            # Override or add the value
            $merged[$key] = $OverrideConfig[$key]
        }
    }
    
    return $merged
}

<#
.SYNOPSIS
    Expand environment variables in configuration
    
.DESCRIPTION
    Internal function to substitute environment variables in configuration values
    using ${VARIABLE_NAME} syntax.
    
.PARAMETER Configuration
    Configuration hashtable to process
#>
function Expand-EnvironmentVariables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    $expanded = @{}
    
    foreach ($key in $Configuration.Keys) {
        if ($Configuration[$key] -is [hashtable]) {
            # Recursively process nested hashtables
            $expanded[$key] = Expand-EnvironmentVariables -Configuration $Configuration[$key]
        }
        elseif ($Configuration[$key] -is [string]) {
            # Expand environment variables in string values
            $value = $Configuration[$key]
            
            # Find all ${VARIABLE_NAME} patterns
            $pattern = '\$\{([^}]+)\}'
            $regexMatches = [regex]::Matches($value, $pattern)
            
            foreach ($match in $regexMatches) {
                $envVarName = $match.Groups[1].Value
                $envVarValue = [Environment]::GetEnvironmentVariable($envVarName)
                
                if ($envVarValue) {
                    $value = $value.Replace($match.Value, $envVarValue)
                    Write-Verbose "Expanded environment variable: $envVarName"
                }
                else {
                    Write-Verbose "Environment variable not found: $envVarName (keeping placeholder)"
                }
            }
            
            $expanded[$key] = $value
        }
        else {
            # Copy non-string, non-hashtable values as-is
            $expanded[$key] = $Configuration[$key]
        }
    }
    
    return $expanded
}

<#
.SYNOPSIS
    Validate configuration for production deployment
    
.DESCRIPTION
    Validates that all required configuration settings are present and properly
    configured for production deployment.
    
.EXAMPLE
    Test-ProductionConfiguration
#>
function Test-ProductionConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        if (-not $script:AppConfig) {
            throw "Configuration not initialized"
        }
        
        $validationErrors = @()
        
        # Check Azure AD configuration
        try {
            $null = Get-AzureADConfiguration
            Write-Verbose "✅ Azure AD configuration valid"
        }
        catch {
            $validationErrors += "Azure AD configuration: $($_.Exception.Message)"
        }
        
        # Check required environment variables for production
        $requiredEnvVars = @("AZURE_TENANT_ID", "AZURE_CLIENT_ID")
        foreach ($envVar in $requiredEnvVars) {
            if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($envVar))) {
                $validationErrors += "Missing environment variable: $envVar"
            }
        }
        
        # Check security settings
        $encryptionEnabled = Get-ConfigurationValue -Path "Security.EncryptionEnabled" -DefaultValue $false
        if (-not $encryptionEnabled) {
            $validationErrors += "Encryption should be enabled for production"
        }
        
        # Check logging level
        $logLevel = Get-ConfigurationValue -Path "Monitoring.LogLevel" -DefaultValue "Information"
        if ($logLevel -eq "Debug") {
            $validationErrors += "Debug logging should not be used in production"
        }
        
        # Report validation results
        if ($validationErrors.Count -eq 0) {
            Write-Information "✅ Production configuration validation passed" -InformationAction Continue
            return $true
        }
        else {
            Write-Warning "❌ Production configuration validation failed:"
            foreach ($validationIssue in $validationErrors) {
                Write-Warning "  - $validationIssue"
            }
            return $false
        }
        
    }
    catch {
        Write-Error "Configuration validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-Configuration',
    'Get-ConfigurationValue',
    'Get-AzureADConfiguration',
    'Get-SecureClientSecret',
    'Test-ProductionConfiguration'
)
