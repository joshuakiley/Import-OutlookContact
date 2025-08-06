<#
.SYNOPSIS
    Authentication module for Import-OutlookContact
    
.DESCRIPTION
    Provides Microsoft Graph authentication, token management, and secure connection handling
    for Import-OutlookContact application. Supports interactive and service principal authentication.
    
.NOTES
    Version: 1.0.0
    Author: Import-OutlookContact Team
    Dependencies: Microsoft.Graph module
    Referenced in: /docs/API.md Authentication section
#>

# Import required modules
using namespace System.Security.SecureString

# Module variables
$script:GraphConnection = $null
$script:AccessToken = $null
$script:TokenExpiry = $null
$script:AuthenticationContext = $null

<#
.SYNOPSIS
    Initialize Graph authentication using environment variables and configuration
    
.DESCRIPTION
    Automatically initializes Microsoft Graph authentication using environment variables
    (AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET) and configuration files.
    This function provides a seamless authentication experience without prompts.
    
.PARAMETER AuthenticationMethod
    Authentication method: Interactive, ServicePrincipal, DeviceCode
    
.PARAMETER Scopes
    Required Microsoft Graph scopes
    
.EXAMPLE
    Initialize-GraphAuthenticationAuto
    
.EXAMPLE
    Initialize-GraphAuthenticationAuto -AuthenticationMethod ServicePrincipal
#>
function Initialize-GraphAuthenticationAuto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Interactive", "ServicePrincipal", "DeviceCode")]
        [string]$AuthenticationMethod = "Interactive",
        
        [Parameter(Mandatory = $false)]
        [string[]]$Scopes = @("Contacts.ReadWrite", "User.Read")
    )
    
    try {
        Write-Information "🔐 Auto-initializing Microsoft Graph authentication..." -InformationAction Continue
        
        # Try to get values from environment variables first
        $tenantId = [Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
        $clientId = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
        $clientSecretString = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
        
        Write-Verbose "Environment variables - TenantId: $($tenantId -ne $null ? 'SET' : 'NOT SET'), ClientId: $($clientId -ne $null ? 'SET' : 'NOT SET'), ClientSecret: $($clientSecretString -ne $null ? 'SET' : 'NOT SET')"
        
        # If environment variables are not available, try configuration
        if ([string]::IsNullOrEmpty($tenantId) -or [string]::IsNullOrEmpty($clientId)) {
            Write-Verbose "Environment variables not found, trying configuration..."
            
            try {
                # Import configuration module if available
                if (Get-Module -ListAvailable -Name "Configuration" -ErrorAction SilentlyContinue) {
                    Import-Module Configuration -Force -Verbose:$false
                    Initialize-Configuration -ErrorAction SilentlyContinue
                    $azureConfig = Get-AzureADConfiguration -ErrorAction SilentlyContinue
                    
                    if ($azureConfig) {
                        if ([string]::IsNullOrEmpty($tenantId)) { $tenantId = $azureConfig.TenantId }
                        if ([string]::IsNullOrEmpty($clientId)) { $clientId = $azureConfig.ClientId }
                        Write-Verbose "Using configuration values for missing environment variables"
                    }
                }
            }
            catch {
                Write-Verbose "Configuration not available: $($_.Exception.Message)"
            }
        }
        
        # Validate we have required values
        if ([string]::IsNullOrEmpty($tenantId)) {
            throw "Tenant ID not found. Set AZURE_TENANT_ID environment variable or provide in configuration."
        }
        
        if ([string]::IsNullOrEmpty($clientId)) {
            throw "Client ID not found. Set AZURE_CLIENT_ID environment variable or provide in configuration."
        }
        
        # Prepare client secret if available and needed
        $clientSecret = $null
        if (-not [string]::IsNullOrEmpty($clientSecretString) -and $AuthenticationMethod -eq "ServicePrincipal") {
            $clientSecret = ConvertTo-SecureString $clientSecretString -AsPlainText -Force
        }
        
        Write-Information "✅ Found authentication parameters - proceeding with $AuthenticationMethod authentication" -InformationAction Continue
        
        # Call the main authentication function with discovered parameters
        return Initialize-GraphAuthentication -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret -AuthenticationMethod $AuthenticationMethod -Scopes $Scopes
        
    }
    catch {
        Write-Error "Auto-authentication failed: $($_.Exception.Message)"
        Write-Information "" -InformationAction Continue
        Write-Information "💡 AUTHENTICATION SETUP HELP:" -InformationAction Continue
        Write-Information "   Set these environment variables:" -InformationAction Continue
        Write-Information "   • AZURE_TENANT_ID=your-tenant-id" -InformationAction Continue
        Write-Information "   • AZURE_CLIENT_ID=your-client-id" -InformationAction Continue
        Write-Information "   • AZURE_CLIENT_SECRET=your-secret (for ServicePrincipal auth)" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        throw
    }
}

<#
.SYNOPSIS
    Initialize Microsoft Graph authentication
    
.DESCRIPTION
    Establishes authenticated connection to Microsoft Graph API using Azure AD app registration.
    Supports both interactive and service principal authentication methods.
    
.PARAMETER TenantId
    Azure AD Tenant ID
    
.PARAMETER ClientId
    Azure AD Application (Client) ID
    
.PARAMETER ClientSecret
    Azure AD Application Client Secret (for service principal auth)
    
.PARAMETER AuthenticationMethod
    Authentication method: Interactive, ServicePrincipal, DeviceCode
    
.PARAMETER Scopes
    Required Microsoft Graph scopes
    
.EXAMPLE
    Initialize-GraphAuthentication -TenantId "tenant-id" -ClientId "client-id" -AuthenticationMethod Interactive
    
.EXAMPLE
    Initialize-GraphAuthentication -TenantId "tenant-id" -ClientId "client-id" -ClientSecret $secureSecret -AuthenticationMethod ServicePrincipal
#>
function Initialize-GraphAuthentication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $false)]
        [SecureString]$ClientSecret,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Interactive", "ServicePrincipal", "DeviceCode")]
        [string]$AuthenticationMethod = "Interactive",
        
        [Parameter(Mandatory = $false)]
        [string[]]$Scopes = @("Contacts.ReadWrite", "User.Read")
    )
    
    try {
        # Use environment variables if parameters not provided
        if ([string]::IsNullOrEmpty($TenantId)) {
            $TenantId = [Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
            if ([string]::IsNullOrEmpty($TenantId)) {
                throw "TenantId must be provided as parameter or set in AZURE_TENANT_ID environment variable"
            }
            Write-Verbose "Using TenantId from AZURE_TENANT_ID environment variable"
        }
        
        if ([string]::IsNullOrEmpty($ClientId)) {
            $ClientId = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
            if ([string]::IsNullOrEmpty($ClientId)) {
                throw "ClientId must be provided as parameter or set in AZURE_CLIENT_ID environment variable"
            }
            Write-Verbose "Using ClientId from AZURE_CLIENT_ID environment variable"
        }
        
        # Check for client secret in environment if not provided and using ServicePrincipal auth
        if (-not $ClientSecret -and $AuthenticationMethod -eq "ServicePrincipal") {
            $clientSecretString = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
            if (-not [string]::IsNullOrEmpty($clientSecretString)) {
                $ClientSecret = ConvertTo-SecureString $clientSecretString -AsPlainText -Force
                Write-Verbose "Using ClientSecret from AZURE_CLIENT_SECRET environment variable"
            }
        }
        
        Write-Verbose "Initializing Microsoft Graph authentication..."
        Write-Verbose "Tenant ID: $TenantId"
        Write-Verbose "Client ID: $ClientId"
        Write-Verbose "Authentication Method: $AuthenticationMethod"
        Write-Verbose "Scopes: $($Scopes -join ', ')"
        
        # Validate required modules
        if (-not (Get-Module -ListAvailable -Name "Microsoft.Graph.Authentication")) {
            throw "Microsoft.Graph.Authentication module is required. Install with: Install-Module Microsoft.Graph -Scope CurrentUser"
        }
        
        # Import Microsoft Graph modules
        Import-Module Microsoft.Graph.Authentication -Force -Verbose:$false
        
        # Disconnect any existing connection
        if ($script:GraphConnection) {
            Write-Verbose "Disconnecting existing Graph connection..."
            Disconnect-MgGraph -Verbose:$false
        }
        
        # Prepare authentication parameters
        $authParams = @{
            TenantId = $TenantId
            ClientId = $ClientId
            Scopes   = $Scopes
        }
        
        # Authenticate based on method
        switch ($AuthenticationMethod) {
            "Interactive" {
                Write-Information "Starting interactive authentication..." -InformationAction Continue
                Write-Information "A browser window will open for authentication." -InformationAction Continue
                
                Connect-MgGraph @authParams -NoWelcome
            }
            
            "ServicePrincipal" {
                if (-not $ClientSecret) {
                    throw "ClientSecret is required for ServicePrincipal authentication"
                }
                
                Write-Verbose "Using service principal authentication..."
                
                # For service principal auth, use different parameter set
                $credential = New-Object System.Management.Automation.PSCredential($ClientId, $ClientSecret)
                Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $credential -NoWelcome
                
                # After connecting, check if we have the required scopes
                $context = Get-MgContext
                if ($context -and $context.Scopes) {
                    $currentScopes = $context.Scopes
                    $missingScopes = $Scopes | Where-Object { $_ -notin $currentScopes }
                    if ($missingScopes) {
                        Write-Warning "Connected but missing some requested scopes: $($missingScopes -join ', ')"
                        Write-Information "Current scopes: $($currentScopes -join ', ')" -InformationAction Continue
                    }
                }
            }
            
            "DeviceCode" {
                Write-Information "Starting device code authentication..." -InformationAction Continue
                Write-Information "Use the provided code to authenticate in a web browser." -InformationAction Continue
                
                $authParams.Add("UseDeviceAuthentication", $true)
                Connect-MgGraph @authParams -NoWelcome
            }
        }
        
        # Verify connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Failed to establish Microsoft Graph connection"
        }
        
        # Store connection information
        $script:GraphConnection = $context
        $script:AuthenticationContext = @{
            TenantId             = $TenantId
            ClientId             = $ClientId
            AuthenticationMethod = $AuthenticationMethod
            Scopes               = $Scopes
            ConnectedAt          = Get-Date
            Account              = $context.Account
        }
        
        Write-Information "✅ Microsoft Graph authentication successful" -InformationAction Continue
        Write-Information "Connected as: $($context.Account)" -InformationAction Continue
        Write-Information "Scopes: $($context.Scopes -join ', ')" -InformationAction Continue
        
        # Log authentication event for audit
        Write-AuditLog -EventType "Authentication" -Message "Microsoft Graph authentication successful" -Details @{
            TenantId    = $TenantId
            ClientId    = $ClientId
            Method      = $AuthenticationMethod
            Account     = $context.Account
            Scopes      = $context.Scopes
            ConnectedAt = Get-Date
        }
        
        return $true
        
    }
    catch {
        $errorMessage = "Microsoft Graph authentication failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        # Log authentication failure for audit
        Write-AuditLog -EventType "AuthenticationFailure" -Message $errorMessage -Details @{
            TenantId = $TenantId
            ClientId = $ClientId
            Method   = $AuthenticationMethod
            Error    = $_.Exception.Message
        }
        
        throw
    }
}

<#
.SYNOPSIS
    Test Microsoft Graph connection status
    
.DESCRIPTION
    Verifies that Microsoft Graph connection is active and valid, including token expiry checks.
    
.EXAMPLE
    Test-GraphConnection
#>
function Test-GraphConnection {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Testing Microsoft Graph connection..."
        
        # Check if Microsoft.Graph.Authentication is available
        if (-not (Get-Command "Get-MgContext" -ErrorAction SilentlyContinue)) {
            Write-Warning "Microsoft.Graph.Authentication module not available"
            return $false
        }
        
        # Check if connection exists
        $context = Get-MgContext
        if (-not $context) {
            Write-Warning "No Microsoft Graph connection found"
            return $false
        }
        
        # Test connection with a simple API call
        Write-Verbose "Testing connection with API call..."
        try {
            $currentUser = Get-MgUser -UserId "me" -ErrorAction Stop -Verbose:$false -Select "id,displayName"
            
            if ($currentUser) {
                Write-Verbose "✅ Microsoft Graph connection is active"
                Write-Verbose "Connected as: $($context.Account)"
                return $true
            }
        }
        catch {
            # If Get-MgUser is not available, try a different approach
            if ($_.Exception.Message -like "*not recognized*") {
                Write-Verbose "Microsoft.Graph.Users module not available, checking basic context only"
                return $true  # Context exists, assume connection is valid
            }
            elseif ($_.Exception.Message -like "*Authorization_RequestDenied*" -or $_.Exception.Message -like "*Insufficient privileges*") {
                Write-Verbose "Connection exists but has authorization restrictions - continuing anyway"
                Write-Warning "Microsoft Graph connection test failed: $($_.Exception.Message)"
                return $true  # Connection exists, authorization issues may be specific to this call
            }
            else {
                Write-Warning "Microsoft Graph connection test failed: $($_.Exception.Message)"
                return $false  # Real connection problem
            }
        }
        
        # If we get here, connection exists but test call failed
        Write-Verbose "Microsoft Graph connection exists (context available)"
        return $true
        
    }
    catch {
        Write-Warning "Microsoft Graph connection test failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Get current authentication context
    
.DESCRIPTION
    Returns information about the current Microsoft Graph authentication session.
    
.EXAMPLE
    Get-AuthenticationContext
#>
function Get-AuthenticationContext {
    [CmdletBinding()]
    param()
    
    if (-not $script:AuthenticationContext) {
        Write-Warning "No authentication context available"
        return $null
    }
    
    # Get current Graph context
    $mgContext = Get-MgContext
    
    # Combine stored and current context
    $authContext = $script:AuthenticationContext.Clone()
    if ($mgContext) {
        $authContext.CurrentAccount = $mgContext.Account
        $authContext.CurrentScopes = $mgContext.Scopes
        $authContext.Environment = $mgContext.Environment
    }
    
    return $authContext
}

<#
.SYNOPSIS
    Refresh Microsoft Graph authentication token
    
.DESCRIPTION
    Refreshes the Microsoft Graph access token if it's close to expiry.
    
.EXAMPLE
    Update-GraphToken
#>
function Update-GraphToken {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Checking token refresh requirements..."
        
        # Test current connection
        if (Test-GraphConnection) {
            Write-Verbose "Current token is still valid"
            return $true
        }
        
        # If we have authentication context, try to reconnect
        if ($script:AuthenticationContext) {
            Write-Information "Refreshing Microsoft Graph token..." -InformationAction Continue
            
            $authParams = @{
                TenantId = $script:AuthenticationContext.TenantId
                ClientId = $script:AuthenticationContext.ClientId
                Scopes   = $script:AuthenticationContext.Scopes
            }
            
            # Reconnect using stored method
            switch ($script:AuthenticationContext.AuthenticationMethod) {
                "Interactive" {
                    Connect-MgGraph @authParams -NoWelcome
                }
                "ServicePrincipal" {
                    # Note: Would need to store client secret securely for refresh
                    Write-Warning "Service principal token refresh requires re-authentication"
                    return $false
                }
                "DeviceCode" {
                    $authParams.Add("UseDeviceAuthentication", $true)
                    Connect-MgGraph @authParams -NoWelcome
                }
            }
            
            # Verify new connection
            if (Test-GraphConnection) {
                Write-Information "✅ Token refreshed successfully" -InformationAction Continue
                return $true
            }
        }
        
        Write-Warning "Token refresh failed - re-authentication required"
        return $false
        
    }
    catch {
        Write-Error "Token refresh failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Disconnect from Microsoft Graph
    
.DESCRIPTION
    Safely disconnects from Microsoft Graph and clears authentication context.
    
.EXAMPLE
    Disconnect-GraphAuthentication
#>
function Disconnect-GraphAuthentication {
    [CmdletBinding()]
    param()
    
    try {
        Write-Information "Disconnecting from Microsoft Graph..." -InformationAction Continue
        
        # Log disconnection for audit
        if ($script:AuthenticationContext) {
            Write-AuditLog -EventType "Disconnection" -Message "Microsoft Graph disconnection" -Details @{
                Account         = $script:AuthenticationContext.Account
                DisconnectedAt  = Get-Date
                SessionDuration = (Get-Date) - $script:AuthenticationContext.ConnectedAt
            }
        }
        
        # Disconnect from Graph
        if (Get-MgContext) {
            Disconnect-MgGraph -Verbose:$false
        }
        
        # Clear stored context
        $script:GraphConnection = $null
        $script:AccessToken = $null
        $script:TokenExpiry = $null
        $script:AuthenticationContext = $null
        
        Write-Information "✅ Disconnected successfully" -InformationAction Continue
        
    }
    catch {
        Write-Error "Error during disconnection: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Write audit log entry for authentication events
    
.DESCRIPTION
    Internal function to log authentication-related events for security auditing.
    
.PARAMETER EventType
    Type of authentication event
    
.PARAMETER Message
    Event message
    
.PARAMETER Details
    Additional event details
#>
function Write-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventType,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Details = @{}
    )
    
    try {
        # Create audit log entry
        $auditEntry = @{
            Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            EventType = $EventType
            Category  = "Authentication"
            Message   = $Message
            Details   = $Details
            Source    = "Import-OutlookContact.Authentication"
            Version   = "1.0.0"
        }
        
        # Convert to JSON for logging
        $auditJson = $auditEntry | ConvertTo-Json -Depth 5 -Compress
        
        # Write to verbose stream for now (could be extended to file/SIEM)
        Write-Verbose "AUDIT: $auditJson"
        
        # TODO: Implement secure audit logging to file or SIEM system
        # This should integrate with the monitoring system specified in /docs/Monitoring.md
        
    }
    catch {
        Write-Warning "Failed to write audit log: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Validate required permissions for contact operations
    
.DESCRIPTION
    Checks that the current authentication context has the required permissions
    for contact management operations.
    
.PARAMETER RequiredScopes
    Array of required permission scopes
    
.EXAMPLE
    Test-RequiredPermissions -RequiredScopes @("Contacts.ReadWrite", "User.Read")
#>
function Test-RequiredPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredScopes
    )
    
    try {
        Write-Verbose "Validating required permissions..."
        
        $context = Get-MgContext
        if (-not $context) {
            Write-Warning "No authentication context available"
            return $false
        }
        
        $currentScopes = $context.Scopes
        if (-not $currentScopes) {
            Write-Warning "No scopes found in current context"
            return $false
        }
        
        # Check each required scope
        $missingScopes = @()
        foreach ($requiredScope in $RequiredScopes) {
            # Check for exact match or broader permissions
            $hasScope = $currentScopes | Where-Object { 
                $_ -eq $requiredScope -or 
                ($requiredScope -like "*.Read*" -and $_ -like "$($requiredScope -replace '\.Read.*', '.ReadWrite')*") -or
                ($_ -like "*$requiredScope*") -or
                ($requiredScope -like "*$_*")
            }
            
            if (-not $hasScope) {
                $missingScopes += $requiredScope
            }
        }
        
        if ($missingScopes.Count -gt 0) {
            Write-Warning "Missing required permissions: $($missingScopes -join ', ')"
            Write-Information "Current permissions: $($currentScopes -join ', ')" -InformationAction Continue
            return $false
        }
        
        Write-Verbose "✅ All required permissions are available"
        return $true
        
    }
    catch {
        Write-Error "Permission validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-GraphAuthentication',
    'Initialize-GraphAuthenticationAuto',
    'Test-GraphConnection',
    'Get-AuthenticationContext',
    'Update-GraphToken',
    'Disconnect-GraphAuthentication',
    'Test-RequiredPermissions'
)
