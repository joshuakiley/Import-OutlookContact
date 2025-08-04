# Deployment and DevOps Guide

This document provides comprehensive guidance for deploying, configuring, and maintaining Import-OutlookContact in production environments.

---

## Overview

Import-OutlookContact supports multiple deployment scenarios from individual workstations to enterprise-scale deployments with high availability and disaster recovery capabilities.

### Deployment Options

| Deployment Type | Use Case                      | Complexity | Scalability  |
| --------------- | ----------------------------- | ---------- | ------------ |
| **Development** | Local testing and development | Low        | Single user  |
| **Workstation** | Individual user deployment    | Low        | Single user  |
| **On-Premises** | Department or organization    | Medium     | 10-100 users |
| **Cloud**       | Enterprise with global reach  | High       | 100+ users   |
| **Hybrid**      | Mixed on-premises and cloud   | High       | Enterprise   |

---

## Quick Deployment

### Development Environment

```powershell
# Clone and setup for development
git clone https://github.com/your-org/Import-OutlookContact.git
cd Import-OutlookContact

# Setup development environment
pwsh .\scripts\Setup-DevEnvironment.ps1 -Mode "Development"

# Run in development mode
pwsh .\Start-ImportOutlookContact.ps1 -Mode Development -Port 5000 -LogLevel Debug
```

### Production Quick Start

```powershell
# Download release package
Invoke-WebRequest -Uri "https://github.com/your-org/Import-OutlookContact/releases/latest/download/import-outlookcontact.zip" -OutFile ".\import-outlookcontact.zip"

# Extract and deploy
Expand-Archive -Path ".\import-outlookcontact.zip" -DestinationPath "C:\Apps\ImportOutlookContact"

# Configure and start
cd "C:\Apps\ImportOutlookContact"
pwsh .\scripts\Initialize-Production.ps1
pwsh .\Start-ImportOutlookContact.ps1 -Mode Production
```

---

## Build and Package

### Build Process

```powershell
# Build application package
pwsh .\scripts\Build-Package.ps1 -Configuration "Release" -OutputPath ".\dist\"

# Build with specific target
pwsh .\scripts\Build-Package.ps1 -Target "Windows" -Architecture "x64"

# Build cross-platform packages
pwsh .\scripts\Build-Package.ps1 -Target "All" -IncludeTests $false
```

### Package Contents

```
import-outlookcontact/
├── Import-OutlookContact.ps1          # Main application
├── Start-ImportOutlookContact.ps1     # Service starter
├── config/
│   ├── appsettings.json              # Application configuration
│   └── appsettings.production.json   # Production overrides
├── modules/                          # PowerShell modules
├── scripts/                          # Utility scripts
├── docs/                            # Documentation
└── templates/                       # Configuration templates
```

### Build Validation

```powershell
# Validate build package
pwsh .\scripts\Test-Package.ps1 -PackagePath ".\dist\import-outlookcontact.zip"

# Run smoke tests
pwsh .\scripts\Test-SmokeTests.ps1 -InstallPath "C:\Temp\TestInstall"
```

---

## Configuration Management

### Configuration Files

#### appsettings.json (Base Configuration)

```json
{
  "Application": {
    "Name": "Import-OutlookContact",
    "Version": "1.0.0",
    "Environment": "Production"
  },
  "AzureAD": {
    "TenantId": "${AZURE_TENANT_ID}",
    "ClientId": "${AZURE_CLIENT_ID}",
    "ClientSecret": "${AZURE_CLIENT_SECRET}",
    "RedirectUri": "http://localhost:8080/auth/callback"
  },
  "Features": {
    "AutoBackup": true,
    "DuplicateDetection": true,
    "CustomFolders": true,
    "AuditLogging": true,
    "PerformanceMonitoring": true
  },
  "Performance": {
    "BatchSize": 500,
    "MaxConcurrentOperations": 4,
    "ImportTimeout": 300,
    "ConnectionPoolSize": 10
  },
  "Security": {
    "EncryptionEnabled": true,
    "AuditLogRetentionDays": 90,
    "SessionTimeoutMinutes": 60,
    "MaxFailedAttempts": 3
  },
  "Monitoring": {
    "HealthCheckInterval": 60,
    "MetricsCollection": true,
    "LogLevel": "Information"
  }
}
```

#### Environment-Specific Overrides

```json
// appsettings.development.json
{
  "AzureAD": {
    "RedirectUri": "http://localhost:5000/auth/callback"
  },
  "Monitoring": {
    "LogLevel": "Debug"
  },
  "Performance": {
    "BatchSize": 10
  }
}

// appsettings.production.json
{
  "AzureAD": {
    "RedirectUri": "https://contacts.yourcompany.com/auth/callback"
  },
  "Security": {
    "AuditLogRetentionDays": 365
  },
  "Monitoring": {
    "LogLevel": "Warning"
  }
}
```

### Environment Variables

```bash
# Required Environment Variables
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"

# Optional Configuration
export LOG_LEVEL="Information"
export BACKUP_RETENTION_DAYS="90"
export MAX_IMPORT_SIZE="10000"
export ENCRYPTION_KEY_PATH="/etc/import-contacts/encryption.key"

# Database Connection (if using external logging)
export LOG_DATABASE_CONNECTION="Server=log-server;Database=ContactLogs;Integrated Security=true"

# Monitoring Integration
export SIEM_ENDPOINT="https://siem.yourcompany.com/api/logs"
export METRICS_ENDPOINT="https://monitoring.yourcompany.com/metrics"
```

### Configuration Validation

```powershell
# Validate configuration before deployment
pwsh .\scripts\Test-Configuration.ps1 -ConfigPath ".\config\appsettings.json"

# Test Azure AD connectivity
pwsh .\scripts\Test-AzureConnection.ps1 -TenantId $env:AZURE_TENANT_ID

# Validate all environment variables
pwsh .\scripts\Test-EnvironmentVariables.ps1 -Required
```

---

## Deployment Scenarios

### Windows Server Deployment

```powershell
# Deploy to Windows Server
pwsh .\deployment\Deploy-WindowsServer.ps1 -ServerName "CONTACT-SRV01" -InstallPath "C:\Apps\ImportContacts"

# Install as Windows Service
pwsh .\deployment\Install-WindowsService.ps1 -ServiceName "ImportOutlookContact" -StartMode "Automatic"

# Configure IIS (if using web interface)
pwsh .\deployment\Configure-IIS.ps1 -SiteName "ImportContacts" -Port 8080
```

#### Windows Service Configuration

```xml
<!-- ImportOutlookContact.service.xml -->
<service>
    <id>ImportOutlookContact</id>
    <name>Import Outlook Contact Service</name>
    <description>Enterprise contact import and management service</description>
    <executable>pwsh.exe</executable>
    <arguments>-File "C:\Apps\ImportContacts\Start-ImportOutlookContact.ps1" -Mode Service</arguments>
    <workingdirectory>C:\Apps\ImportContacts</workingdirectory>
    <startmode>Automatic</startmode>
    <env name="AZURE_TENANT_ID" value="your-tenant-id"/>
    <env name="AZURE_CLIENT_ID" value="your-client-id"/>
</service>
```

### Linux Server Deployment

```bash
# Deploy to Linux server
./deployment/deploy-linux.sh --server 192.168.1.100 --path /opt/import-contacts

# Install systemd service
sudo ./deployment/install-systemd-service.sh

# Configure reverse proxy (nginx)
sudo ./deployment/configure-nginx.sh --domain contacts.yourcompany.com
```

#### Systemd Service Configuration

```ini
# /etc/systemd/system/import-outlookcontact.service
[Unit]
Description=Import Outlook Contact Service
After=network.target

[Service]
Type=simple
User=contactsvc
WorkingDirectory=/opt/import-contacts
ExecStart=/usr/bin/pwsh -File /opt/import-contacts/Start-ImportOutlookContact.ps1 -Mode Service
Restart=always
RestartSec=10

Environment=AZURE_TENANT_ID=your-tenant-id
Environment=AZURE_CLIENT_ID=your-client-id
Environment=AZURE_CLIENT_SECRET=your-client-secret

[Install]
WantedBy=multi-user.target
```

### Docker Deployment

#### Dockerfile

```dockerfile
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy application files
COPY . .

# Install PowerShell modules
RUN pwsh -Command "Install-Module Microsoft.Graph -Force -Scope AllUsers"
RUN pwsh -Command "Install-Module UniversalDashboard.Community -Force -Scope AllUsers"

# Create non-root user
RUN useradd -m -s /bin/bash contactsvc
RUN chown -R contactsvc:contactsvc /app
USER contactsvc

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start application
CMD ["pwsh", "-File", "./Start-ImportOutlookContact.ps1", "-Mode", "Production", "-Port", "8080"]
```

#### Docker Compose

```yaml
version: "3.8"

services:
  import-outlookcontact:
    build: .
    ports:
      - "8080:8080"
    environment:
      - AZURE_TENANT_ID=${AZURE_TENANT_ID}
      - AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
      - AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
      - LOG_LEVEL=Information
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
      - ./backups:/app/backups
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  reverse-proxy:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - import-outlookcontact
    restart: unless-stopped
```

### Azure Cloud Deployment

#### Azure App Service

```powershell
# Deploy to Azure App Service
pwsh .\deployment\Deploy-AzureAppService.ps1 -ResourceGroup "rg-contacts" -AppName "import-contacts" -Location "East US"

# Configure application settings
pwsh .\deployment\Set-AzureAppSettings.ps1 -AppName "import-contacts" -SettingsFile ".\config\azure-appsettings.json"

# Enable monitoring
pwsh .\deployment\Enable-AzureMonitoring.ps1 -AppName "import-contacts" -LogAnalyticsWorkspace "contacts-logs"
```

#### Azure Container Instances

```powershell
# Deploy to Azure Container Instances
pwsh .\deployment\Deploy-AzureContainerInstance.ps1 -ResourceGroup "rg-contacts" -ContainerName "import-contacts" -Image "youracr.azurecr.io/import-outlookcontact:latest"

# Configure auto-scaling
pwsh .\deployment\Configure-AzureAutoScale.ps1 -ResourceGroup "rg-contacts" -MinInstances 1 -MaxInstances 5
```

#### Azure Resource Manager Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "appName": {
      "type": "string",
      "metadata": {
        "description": "Name of the App Service"
      }
    },
    "azureTenantId": {
      "type": "securestring",
      "metadata": {
        "description": "Azure AD Tenant ID"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2021-02-01",
      "name": "[concat(parameters('appName'), '-plan')]",
      "location": "[resourceGroup().location]",
      "sku": {
        "name": "P1v2",
        "capacity": 1
      }
    },
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2021-02-01",
      "name": "[parameters('appName')]",
      "location": "[resourceGroup().location]",
      "dependsOn": [
        "[resourceId('Microsoft.Web/serverfarms', concat(parameters('appName'), '-plan'))]"
      ],
      "properties": {
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', concat(parameters('appName'), '-plan'))]",
        "siteConfig": {
          "appSettings": [
            {
              "name": "AZURE_TENANT_ID",
              "value": "[parameters('azureTenantId')]"
            }
          ]
        }
      }
    }
  ]
}
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup PowerShell
        uses: microsoft/setup-powershell@v1

      - name: Install Dependencies
        run: |
          pwsh -Command "Install-Module Microsoft.Graph -Force -Scope CurrentUser"
          pwsh -Command "Install-Module Pester -Force -Scope CurrentUser"

      - name: Run Tests
        run: |
          pwsh .\scripts\Invoke-AllTests.ps1 -Coverage -OutputPath ".\test-results\"

      - name: Upload Test Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/

      - name: Security Scan
        run: |
          pwsh .\scripts\Test-SecurityCompliance.ps1 -OutputPath ".\security-results\"

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Package
        run: |
          pwsh .\scripts\Build-Package.ps1 -Configuration "Release" -OutputPath ".\dist\"

      - name: Upload Build Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-artifacts
          path: dist/

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
      - name: Download Artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-artifacts

      - name: Deploy to Staging
        run: |
          pwsh .\deployment\Deploy-AzureAppService.ps1 -ResourceGroup "rg-contacts-staging" -AppName "import-contacts-staging"

  deploy-production:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Download Artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-artifacts

      - name: Deploy to Production
        run: |
          pwsh .\deployment\Deploy-AzureAppService.ps1 -ResourceGroup "rg-contacts-prod" -AppName "import-contacts-prod"

      - name: Run Smoke Tests
        run: |
          pwsh .\scripts\Test-SmokeTests.ps1 -BaseUrl "https://import-contacts-prod.azurewebsites.net"
```

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  - main
  - develop

pool:
  vmImage: "windows-latest"

variables:
  buildConfiguration: "Release"

stages:
  - stage: Test
    jobs:
      - job: UnitTests
        steps:
          - task: PowerShell@2
            inputs:
              filePath: "scripts/Invoke-AllTests.ps1"
              arguments: '-Coverage -OutputPath "$(Agent.TempDirectory)/test-results"'

          - task: PublishTestResults@2
            inputs:
              testResultsFormat: "NUnit"
              testResultsFiles: "$(Agent.TempDirectory)/test-results/TestResults.xml"

  - stage: Build
    jobs:
      - job: BuildPackage
        steps:
          - task: PowerShell@2
            inputs:
              filePath: "scripts/Build-Package.ps1"
              arguments: '-Configuration $(buildConfiguration) -OutputPath "$(Build.ArtifactStagingDirectory)"'

          - task: PublishBuildArtifacts@1
            inputs:
              artifactName: "drop"

  - stage: Deploy
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployProduction
        environment: "production"
        strategy:
          runOnce:
            deploy:
              steps:
                - task: PowerShell@2
                  inputs:
                    filePath: "deployment/Deploy-AzureAppService.ps1"
                    arguments: '-ResourceGroup "rg-contacts" -AppName "import-contacts"'
```

---

## Secrets Management

### Azure Key Vault Integration

```powershell
# Store secrets in Azure Key Vault
pwsh .\scripts\Store-Secrets.ps1 -KeyVaultName "contacts-keyvault" -Secrets @{
    "AzureClientSecret" = $clientSecret
    "DatabaseConnection" = $connectionString
    "EncryptionKey" = $encryptionKey
}

# Retrieve secrets at runtime
$secrets = Get-AzKeyVaultSecrets -VaultName "contacts-keyvault"
$env:AZURE_CLIENT_SECRET = $secrets["AzureClientSecret"]
```

### Environment-Specific Secrets

```powershell
# Development secrets (local development only)
$env:AZURE_CLIENT_SECRET = "dev-client-secret"

# Production secrets (from secure source)
$env:AZURE_CLIENT_SECRET = Get-AzKeyVaultSecret -VaultName "prod-keyvault" -Name "ClientSecret" -AsPlainText
```

### Secret Rotation

```powershell
# Automated secret rotation
pwsh .\scripts\Rotate-Secrets.ps1 -KeyVaultName "contacts-keyvault" -SecretName "AzureClientSecret"

# Verify secret rotation
pwsh .\scripts\Test-SecretRotation.ps1 -KeyVaultName "contacts-keyvault"
```

---

## Monitoring and Health Checks

### Health Endpoints

```powershell
# Configure health check endpoints
$healthChecks = @{
    "/health" = "Basic health status"
    "/health/detailed" = "Comprehensive system status"
    "/health/dependencies" = "External service connectivity"
    "/metrics" = "Performance metrics"
}
```

### Application Insights Integration

```powershell
# Configure Application Insights
pwsh .\scripts\Configure-ApplicationInsights.ps1 -InstrumentationKey $instrumentationKey

# Custom telemetry
Send-CustomTelemetry -EventName "ContactImport" -Properties @{
    "UserEmail" = $userEmail
    "ContactCount" = $contactCount
    "Duration" = $duration
}
```

### SIEM Integration

```powershell
# Forward logs to SIEM
pwsh .\scripts\Configure-SIEMForwarding.ps1 -SIEMEndpoint "https://siem.company.com/api/logs"

# Send security events
Send-SecurityEvent -EventType "ImportAttempt" -Details @{
    "User" = $userEmail
    "SourceIP" = $sourceIP
    "Success" = $success
}
```

---

## Rollback and Recovery

### Deployment Rollback

```powershell
# Quick rollback to previous version
pwsh .\deployment\Rollback-Deployment.ps1 -TargetVersion "1.2.0" -Environment "Production"

# Rollback with database migration
pwsh .\deployment\Rollback-WithDatabase.ps1 -TargetVersion "1.2.0" -BackupDatabase $true
```

### Blue-Green Deployment

```powershell
# Deploy to green environment
pwsh .\deployment\Deploy-BlueGreen.ps1 -Environment "Green" -Version "1.3.0"

# Switch traffic to green
pwsh .\deployment\Switch-Traffic.ps1 -From "Blue" -To "Green"

# Rollback traffic if needed
pwsh .\deployment\Switch-Traffic.ps1 -From "Green" -To "Blue"
```

### System Recovery

```powershell
# Create system checkpoint before deployment
pwsh .\admin\New-SystemCheckpoint.ps1 -CheckpointName "PreDeployment-v1.3.0"

# Restore from checkpoint
pwsh .\admin\Restore-SystemCheckpoint.ps1 -CheckpointName "PreDeployment-v1.3.0"

# Verify system health after recovery
pwsh .\scripts\Test-SystemHealth.ps1 -Detailed
```

---

## Maintenance Procedures

### Regular Maintenance Tasks

```powershell
# Daily maintenance script
pwsh .\maintenance\Daily-Maintenance.ps1

# Weekly maintenance
pwsh .\maintenance\Weekly-Maintenance.ps1 -CleanupLogs $true -UpdateMetrics $true

# Monthly maintenance
pwsh .\maintenance\Monthly-Maintenance.ps1 -RotateSecrets $true -UpdateDependencies $true
```

### Database Maintenance

```powershell
# Cleanup old audit logs
pwsh .\maintenance\Cleanup-AuditLogs.ps1 -RetentionDays 90

# Optimize database performance
pwsh .\maintenance\Optimize-Database.ps1 -UpdateStatistics $true -RebuildIndexes $true

# Backup database
pwsh .\maintenance\Backup-Database.ps1 -BackupPath "\\backup\database\" -Compress $true
```

### Performance Optimization

```powershell
# Analyze performance metrics
pwsh .\maintenance\Analyze-Performance.ps1 -TimeRange "Last30Days" -GenerateReport $true

# Optimize application settings
pwsh .\maintenance\Optimize-Settings.ps1 -Profile "HighVolume"

# Update caching configuration
pwsh .\maintenance\Update-CacheSettings.ps1 -CacheSize "1GB" -ExpirationTime "1Hour"
```

---

## Troubleshooting Deployment Issues

### Common Deployment Problems

#### PowerShell Module Issues

```powershell
# Fix module installation issues
pwsh .\troubleshooting\Fix-ModuleIssues.ps1 -Force -Verbose

# Update all modules
pwsh .\troubleshooting\Update-AllModules.ps1 -AllowPrerelease $false
```

#### Permission Issues

```powershell
# Fix file permissions
pwsh .\troubleshooting\Fix-FilePermissions.ps1 -Path "C:\Apps\ImportContacts" -Recurse

# Test Azure AD permissions
pwsh .\troubleshooting\Test-AzurePermissions.ps1 -TenantId $tenantId -ClientId $clientId
```

#### Network Connectivity

```powershell
# Test network connectivity
pwsh .\troubleshooting\Test-NetworkConnectivity.ps1 -Endpoints @("graph.microsoft.com", "login.microsoftonline.com")

# Test firewall rules
pwsh .\troubleshooting\Test-FirewallRules.ps1 -Ports @(80, 443, 8080)
```

### Diagnostic Data Collection

```powershell
# Collect comprehensive diagnostics
pwsh .\troubleshooting\Collect-DiagnosticData.ps1 -OutputPath ".\diagnostics\" -IncludeSystemInfo $true

# Generate support bundle
pwsh .\troubleshooting\Generate-SupportBundle.ps1 -OutputPath ".\support-bundle.zip"
```

---

## Security Considerations

### Deployment Security

- **Secure Communication** - Always use HTTPS/TLS for web interfaces
- **Authentication** - Implement proper authentication and authorization
- **Secrets Management** - Never store secrets in configuration files
- **Network Security** - Configure firewalls and network segmentation
- **Access Control** - Implement principle of least privilege

### Security Validation

```powershell
# Security assessment
pwsh .\security\Assess-DeploymentSecurity.ps1 -Detailed

# Vulnerability scan
pwsh .\security\Scan-Vulnerabilities.ps1 -OutputPath ".\security-report.html"

# Compliance check
pwsh .\security\Test-ComplianceRequirements.ps1 -Standards @("SOC2", "GDPR", "ISO27001")
```

---

## Performance Tuning

### Application Performance

```powershell
# Configure performance settings
pwsh .\scripts\Configure-Performance.ps1 -Profile "HighThroughput" -MaxConcurrentUsers 100

# Monitor performance metrics
pwsh .\scripts\Monitor-Performance.ps1 -Duration "1Hour" -Interval "5Minutes"
```

### Infrastructure Optimization

- **CPU and Memory** - Size appropriately for expected load
- **Storage** - Use fast storage for temporary files and logs
- **Network** - Ensure adequate bandwidth for Graph API calls
- **Caching** - Configure appropriate caching strategies

---

This deployment guide provides comprehensive coverage of all deployment scenarios and operational procedures for Import-OutlookContact. Regular updates to this documentation ensure it remains current with evolving infrastructure and security requirements.
