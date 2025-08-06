# Import-OutlookContact

**Import-OutlookContact** is a cross-platform enterprise contact management solution with a **Svelte + TailwindCSS + TypeScript** web interface and PowerShell backend, leveraging Microsoft Graph for secure, scalable Outlook contact operations.

---

## 🛠️ Technology Stack

### Frontend (Web UI)

- **Framework:** Svelte 4+ with SvelteKit
- **Styling:** TailwindCSS 3+ with custom design system
- **Language:** TypeScript 5+ with strict mode
- **Testing:** Vitest + Playwright + Testing Library/Svelte
- **Security:** ESLint Security Plugin + OWASP compliance

### Backend (API & CLI)

- **Runtime:** PowerShell 7+ (cross-platform)
- **API:** REST endpoints with JSON communication
- **Authentication:** Microsoft Graph with OAuth 2.0/OpenID Connect
- **Database:** Secure file-based storage with encryption

---

## 🎯 Key Features

- **🌐 Modern Web Interface:** Responsive Svelte UI with enterprise-grade security and accessibility
- **👥 Multi-User Management:** Bulk operations across multiple users and contact folders
- **📂 Advanced Import Support:** vCard (.vcf), Google CSV, Outlook CSV, and generic CSV with field mapping
- **💾 Backup & Restore:** Automatic backups with preview functionality and point-in-time recovery
- **🔍 Smart Duplicate Detection:** AI-powered duplicate detection with intelligent merging capabilities
- **📁 Custom Folder Support:** Enterprise folder management (Vendors, Contractors, Clients)
- **🔐 Enterprise Security:** OAuth 2.0, CSRF protection, XSS prevention, audit logging
- **♿ Accessibility:** WCAG 2.1 AA compliant with full keyboard navigation and screen reader support
- **🔌 Extensible Architecture:** Plugin system for HRIS, ticketing, and workflow integrations
- **🛡️ GDPR Compliant:** Privacy by design with comprehensive data protection
- **🌍 Cross-Platform:** Windows, macOS, and Linux support

---

## 🚀 Quick Start

### Prerequisites

**Backend Requirements:**

- PowerShell 7.x ([Install Guide](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell))
- Azure App Registration with `Contacts.ReadWrite` permission
- Microsoft Graph PowerShell SDK

**Frontend Requirements:**

- Node.js 18+ with npm/pnpm
- Modern web browser with JavaScript enabled

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR-ORG/Import-OutlookContact.git
cd Import-OutlookContact

# Backend setup
pwsh -c "Install-Module Microsoft.Graph -Scope CurrentUser"
pwsh ./scripts/Test-Prerequisites.ps1

# Frontend setup
cd web-ui
npm install
npm run build

# Configure the application
cd ..
pwsh ./scripts/Set-InitialConfiguration.ps1
```

### Basic Usage

**Web Interface:**

```bash
# Start the modern Svelte web interface
./start-web-interface.sh

# Or manually:
cd web-ui
npm install
npm run build
npm run preview
```

**CLI Mode:**

```powershell
# Interactive CSV Import with Duplicate Handling (Recommended)
pwsh ./scripts/Import-CSVWithDuplicateHandling.ps1 "./csv-files/your-file.csv"

# Traditional CLI Mode
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ./contacts.csv

# Setup and Testing Scripts
pwsh ./scripts/Setup-Environment.ps1        # First-time setup
pwsh ./scripts/Test-Prerequisites.ps1       # Verify requirements
pwsh ./scripts/Test-Authentication.ps1      # Test Graph connection
```

### CSV Format Example

| FirstName | LastName | Email             | Phone      | Company | JobTitle |
| --------- | -------- | ----------------- | ---------- | ------- | -------- |
| Alice     | Smith    | alice@example.com | 1234567890 | Org1    | Analyst  |
| Bob       | Johnson  | bob@example.com   | 0987654321 | Org2    | Engineer |

---

## Documentation

📚 **[Complete Documentation Index](/docs/Documentation-Index.md)** - Comprehensive guide to all documentation

### Quick Reference

- **[UI/UX Specifications](/docs/UI-Spec.md)** - Complete interface design, wireframes, and user workflows
- **[Import & Data Management](/docs/Import-DataManagement.md)** - Advanced import features, backup/restore, duplicate management
- **[Administrative Features](/docs/Admin-Features.md)** - IT tools, deployment scripts, and enterprise management
- **[Testing & Validation](/docs/Testing-Validation.md)** - Comprehensive testing framework and quality assurance

### Enterprise Features

- **[Plugin Architecture](/docs/Plugin-Architecture.md)** - Extension API, HRIS integrations, and third-party connections
- **[Data Privacy & GDPR](/docs/DataPrivacy-GDPR.md)** - Privacy compliance, data subject rights, and regulatory adherence
- **[Change Approval Workflows](/docs/ChangeApproval.md)** - Multi-tier approval processes and governance

### Operations & Support

- **[Deployment Guide](/docs/Deploy.md)** - DevOps, CI/CD, deployment automation, and maintenance procedures
- **[API Reference](/docs/API.md)** - Complete PowerShell commands and REST endpoint documentation
- **[Monitoring & Health Checks](/docs/Monitoring.md)** - Real-time monitoring, performance metrics, and alerting
- **[Disaster Recovery](/docs/DisasterRecovery.md)** - Business continuity, incident response, and recovery planning
- **[Accessibility Guide](/docs/Accessibility.md)** - WCAG 2.1 compliance and assistive technology support

### Project Information

- **[Contributing Guidelines](./CONTRIBUTING.md)** - How to contribute, coding standards, and development workflows
- **[Support Resources](./SUPPORT.md)** - Getting help, reporting issues, and professional support options
- **[Change Log](./CHANGELOG.md)** - Version history, release notes, and upcoming features

---

## Features in Detail

### Import Capabilities

#### Multi-Format Support

- **vCard (.vcf)** - iPhone, Android, Mac, and most CRM exports
- **Google Contacts CSV** - Gmail and Google Workspace exports with auto-detection
- **Outlook CSV** - All Outlook versions and Office 365 formats
- **Generic CSV** - Any CSV file with custom field mapping

#### Advanced Processing

- **Intelligent Field Mapping** - Automatic detection with manual override capabilities
- **Preview and Edit** - Review and modify contacts before import
- **Batch Processing** - Handle large datasets efficiently (1000+ contacts)
- **Error Handling** - Comprehensive validation and error recovery

### Data Management

#### Backup and Restore

- **Automatic Backups** - Created before any contact modifications
- **Manual Backups** - On-demand backup with encryption support
- **Selective Restore** - Restore specific folders or date ranges
- **Preview Restore** - Review changes before applying

#### Duplicate Management

- **Flexible Detection** - Match by email, phone, or custom criteria
- **Intelligent Merging** - Combine contact information with conflict resolution
- **Fallback Matching** - Handle contacts without email addresses
- **Batch Operations** - Process multiple duplicates efficiently

#### Custom Organization

- **Business Folders** - Vendors, Contractors, Clients, Partners
- **Department Assignment** - Role-based folder access and management
- **Bulk Operations** - Move and organize contacts at scale
- **Contact Migration** - Transfer contacts between folders

### Enterprise Features

#### Security and Compliance

- **Azure AD Integration** - Enterprise-grade authentication
- **Audit Trails** - Immutable logging of all operations
- **Encryption** - Data protection in transit and at rest
- **GDPR Compliance** - Privacy by design with data subject rights

#### Administration

- **Multi-User Management** - Bulk operations across users
- **Role-Based Access** - Granular permissions and controls
- **Monitoring and Alerting** - Real-time system health and performance
- **Disaster Recovery** - Business continuity and data protection

---

## Architecture

### System Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │    │  PowerShell     │    │  Microsoft      │
│   (Any Device)  │◄──►│  Universal      │◄──►│  Graph API      │
│                 │    │  Dashboard      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Contact Data   │
                       │  Processing     │
                       │  Engine         │
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Audit & Log    │
                       │  System         │
                       └─────────────────┘
```

### Technical Stack

- **Frontend:** Svelte + TailwindCSS + TypeScript (modern reactive web interface)
- **Backend:** PowerShell 7 with Microsoft Graph PowerShell SDK
- **Authentication:** Azure AD OAuth 2.0 with Microsoft Authenticator and passkey support
- **Data Storage:** Microsoft 365 (contacts stored in user Outlook folders)
- **Logging:** Immutable audit trails with SIEM-compatible export formats
- **Security:** TLS encryption, Azure AD integration, role-based access control

### Deployment Options

- **Cloud:** Azure App Service, Azure Container Instances
- **On-Premises:** Windows Server, Linux servers, Docker containers
- **Hybrid:** Cloud management with on-premises data processing
- **Desktop:** Individual workstation deployment

---

## Advanced Usage

### Command Line Interface

#### Bulk Import Operations

```powershell
# Import with custom folder assignment
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ./vendors.csv -TargetFolder "Vendors"

# Import with duplicate detection
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ./contacts.csv -DuplicateAction "Merge"

# Import with custom field mapping
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ./contacts.csv -MappingProfile "CustomProfile1"
```

#### Backup and Restore

```powershell
# Create backup before major operation
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -BackupType "Full"

# Restore from specific backup
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -BackupDate "2024-08-04" -Preview

# Selective restore
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -Folders @("Vendors", "Clients") -BackupDate "2024-08-04"
```

#### Administrative Operations

```powershell
# Bulk folder assignment
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "Sales" -Folders @("Clients", "Partners")

# System health check
pwsh .\admin\Test-SystemHealth.ps1 -Detailed -OutputPath ".\reports\health-check.html"

# Performance monitoring
pwsh .\admin\Get-PerformanceMetrics.ps1 -TimeRange "Last24Hours" -Export "Excel"
```

### Web Interface Features

#### Import Wizard

1. **File Upload** - Drag and drop or browse for files
2. **Format Detection** - Automatic file type recognition
3. **Field Mapping** - Visual mapping interface with preview
4. **Duplicate Review** - Side-by-side comparison and merge options
5. **Folder Assignment** - Select or create target folders
6. **Import Execution** - Real-time progress with detailed logging

#### Dashboard Features

- **Import History** - View all past import operations
- **Contact Statistics** - User and folder contact counts
- **System Health** - Real-time monitoring and alerts
- **Backup Management** - View, create, and restore backups
- **User Management** - Role assignment and permissions

---

## Configuration

### Azure App Registration

```powershell
# Required Microsoft Graph permissions
$permissions = @(
    "Contacts.ReadWrite",
    "User.Read.All",
    "Directory.Read.All"
)

# Optional permissions for enhanced features
$optionalPermissions = @(
    "AuditLog.Read.All",
    "Reports.Read.All"
)
```

### Application Settings

```json
{
  "AzureAD": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "ClientSecret": "your-client-secret"
  },
  "Features": {
    "AutoBackup": true,
    "DuplicateDetection": true,
    "CustomFolders": true,
    "AuditLogging": true
  },
  "Performance": {
    "BatchSize": 500,
    "MaxConcurrentOperations": 4,
    "ImportTimeout": 300
  }
}
```

### Environment Variables

```bash
# Required
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"

# Optional
export LOG_LEVEL="Information"
export BACKUP_RETENTION_DAYS="90"
export MAX_IMPORT_SIZE="10000"
```

---

## Deployment

### Production Deployment

#### Docker Deployment

```bash
# Build container
docker build -t import-outlookcontact:latest .

# Run with environment variables
docker run -d \
  --name import-outlookcontact \
  -p 8080:8080 \
  -e AZURE_TENANT_ID="your-tenant-id" \
  -e AZURE_CLIENT_ID="your-client-id" \
  -e AZURE_CLIENT_SECRET="your-client-secret" \
  import-outlookcontact:latest
```

#### Azure Deployment

```powershell
# Deploy to Azure App Service
pwsh .\deployment\Deploy-AzureAppService.ps1 -ResourceGroup "rg-contacts" -AppName "import-contacts"

# Deploy to Azure Container Instances
pwsh .\deployment\Deploy-AzureContainerInstance.ps1 -ResourceGroup "rg-contacts" -ContainerName "import-contacts"
```

#### On-Premises Deployment

```powershell
# Windows Server deployment
pwsh .\deployment\Deploy-WindowsServer.ps1 -ServerName "CONTACT-SRV01" -InstallPath "C:\Apps\ImportContacts"

# Linux server deployment
pwsh .\deployment\Deploy-LinuxServer.ps1 -ServerIP "192.168.1.100" -InstallPath "/opt/import-contacts"
```

### Development Environment

```powershell
# Setup development environment
pwsh .\scripts\Setup-DevEnvironment.ps1

# Run in development mode
pwsh .\Start-ImportOutlookContact.ps1 -Mode Development -Port 5000

# Enable debug logging
pwsh .\Start-ImportOutlookContact.ps1 -LogLevel Debug -EnableTracing
```

---

## Monitoring and Maintenance

### Health Monitoring

#### System Health Endpoints

- `/health` - Basic health check
- `/health/detailed` - Comprehensive system status
- `/health/dependencies` - External service connectivity
- `/metrics` - Performance metrics and statistics

#### Performance Metrics

- Import operations per hour
- Average import processing time
- Memory and CPU utilization
- API call success rates
- Error rates and types

### Maintenance Tasks

#### Regular Maintenance

```powershell
# Daily backup verification
pwsh .\maintenance\Verify-Backups.ps1 -Days 7

# Weekly performance report
pwsh .\maintenance\Generate-PerformanceReport.ps1 -OutputPath ".\reports\"

# Monthly cleanup
pwsh .\maintenance\Cleanup-OldLogs.ps1 -RetentionDays 90
```

#### Troubleshooting Tools

```powershell
# Diagnostic information collection
pwsh .\troubleshooting\Collect-Diagnostics.ps1 -OutputPath ".\diagnostics\"

# Connection testing
pwsh .\troubleshooting\Test-Connectivity.ps1 -Detailed

# Performance analysis
pwsh .\troubleshooting\Analyze-Performance.ps1 -TimeRange "Last4Hours"
```

## Security Considerations

### Data Protection

- **Encryption:** All data encrypted in transit (TLS 1.2+) and at rest (AES-256)
- **Authentication:** Azure AD OAuth 2.0 with multi-factor authentication support
- **Authorization:** Role-based access control with principle of least privilege
- **Audit Logging:** Comprehensive, immutable audit trails for all operations

### Compliance Features

- **GDPR:** Right to be forgotten, data portability, consent management
- **SOC 2:** Type II compliance with security and availability controls
- **ISO 27001:** Information security management system alignment
- **HIPAA:** Healthcare data protection capabilities (when configured)

### Security Best Practices

```powershell
# Enable security features
pwsh .\security\Enable-SecurityFeatures.ps1 -Profile "Enterprise"

# Security audit
pwsh .\security\Run-SecurityAudit.ps1 -OutputPath ".\reports\security-audit.html"

# Vulnerability assessment
pwsh .\security\Test-Vulnerabilities.ps1 -Detailed
```

---

## Performance and Scalability

### Performance Benchmarks

- **Small Import (1-100 contacts):** < 30 seconds
- **Medium Import (100-1,000 contacts):** < 5 minutes
- **Large Import (1,000-10,000 contacts):** < 30 minutes
- **Concurrent Users:** Up to 100 simultaneous users
- **API Rate Limits:** Intelligent throttling and retry logic

### Optimization Features

- **Batch Processing:** Configurable batch sizes for optimal throughput
- **Parallel Processing:** Multi-threaded operations where applicable
- **Caching:** Intelligent caching of user data and metadata
- **Connection Pooling:** Efficient Microsoft Graph API connection management

### Scalability Options

- **Horizontal Scaling:** Load balancer support for multiple instances
- **Vertical Scaling:** Multi-core CPU and high-memory configurations
- **Cloud Scaling:** Auto-scaling in Azure App Service environments
- **Database Scaling:** Distributed logging and audit storage

---

## Troubleshooting

### Common Issues

#### Import Problems

```powershell
# File format issues
pwsh .\troubleshooting\Test-ImportFile.ps1 -FilePath ".\problematic-file.csv" -Detailed

# Permission issues
pwsh .\troubleshooting\Test-Permissions.ps1 -UserEmail "user@domain.com"

# Duplicate detection issues
pwsh .\troubleshooting\Debug-DuplicateDetection.ps1 -Verbose
```

#### Authentication Issues

```powershell
# Test Azure AD connection
pwsh .\troubleshooting\Test-AzureADConnection.ps1

# Refresh authentication tokens
pwsh .\troubleshooting\Refresh-AuthTokens.ps1 -Force

# Check permissions
pwsh .\troubleshooting\Test-GraphPermissions.ps1 -ShowMissing
```

#### Performance Issues

```powershell
# Performance diagnostics
pwsh .\troubleshooting\Diagnose-Performance.ps1 -TimeRange "Last1Hour"

# Memory analysis
pwsh .\troubleshooting\Analyze-Memory.ps1 -GenerateReport

# Network connectivity
pwsh .\troubleshooting\Test-NetworkLatency.ps1 -Detailed
```

### Log Analysis

```powershell
# View recent errors
pwsh .\troubleshooting\Get-RecentErrors.ps1 -Hours 24

# Search logs
pwsh .\troubleshooting\Search-Logs.ps1 -Pattern "import failed" -Days 7

# Export diagnostic logs
pwsh .\troubleshooting\Export-DiagnosticLogs.ps1 -OutputPath ".\support-case-logs.zip"
```

---

## API Reference

### REST API Endpoints

#### Import Operations

```http
POST /api/import/upload
POST /api/import/preview
POST /api/import/execute
GET /api/import/status/{importId}
GET /api/import/history
```

#### Contact Management

```http
GET /api/contacts/{userId}
GET /api/contacts/{userId}/folders
POST /api/contacts/{userId}/folders
DELETE /api/contacts/{userId}/folders/{folderId}
```

#### Backup Operations

```http
POST /api/backup/{userId}
GET /api/backup/{userId}/list
POST /api/restore/{userId}
GET /api/restore/status/{restoreId}
```

### PowerShell Module

#### Core Functions

```powershell
# Import functions
Import-ContactsFromFile
Get-ImportHistory
Test-ImportFile

# Backup functions
New-ContactBackup
Restore-ContactBackup
Get-BackupHistory

# Management functions
New-ContactFolder
Move-ContactsToFolder
Find-DuplicateContacts
```

#### Usage Examples

```powershell
# Import with all options
Import-ContactsFromFile -FilePath ".\contacts.vcf" -UserEmail "user@domain.com" -TargetFolder "Vendors" -DuplicateAction "Merge" -CreateBackup

# Advanced backup
New-ContactBackup -UserEmail "user@domain.com" -IncludeFolders @("Vendors", "Clients") -Encrypt -RetentionDays 365

# Bulk operations
$users = @("user1@domain.com", "user2@domain.com")
$users | ForEach-Object { New-ContactFolder -UserEmail $_ -FolderName "Contractors" }
```

---

## FAQ

### General Questions

**Q: What file formats are supported for import?**
A: vCard (.vcf), Google Contacts CSV, Outlook CSV, and generic CSV files with custom field mapping.

**Q: Can I import iPhone contacts?**
A: Yes, export your iPhone contacts as vCard (.vcf) format and import directly.

**Q: How many contacts can I import at once?**
A: The system can handle up to 10,000 contacts per import operation.

**Q: Are backups created automatically?**
A: Yes, automatic backups are created before any contact modification operations.

### Technical Questions

**Q: What PowerShell version is required?**
A: PowerShell 7.0 or later for cross-platform compatibility.

**Q: Which Microsoft Graph permissions are needed?**
A: At minimum: `Contacts.ReadWrite`, `User.Read.All`. Full feature set requires additional permissions documented in the admin guide.

**Q: Can this run on Linux or macOS?**
A: Yes, full cross-platform support with PowerShell 7+.

**Q: Is there an API for integration?**
A: Yes, comprehensive REST API for all operations. See API Reference section.

### Enterprise Questions

**Q: How is data secured?**
A: Azure AD authentication, TLS encryption, audit logging, and role-based access control.

**Q: Is this GDPR compliant?**
A: Yes, with built-in privacy features including right to be forgotten and data portability.

**Q: Can I deploy this in my datacenter?**
A: Yes, on-premises deployment is supported on Windows Server and Linux.

**Q: What monitoring capabilities are included?**
A: Health endpoints, performance metrics, error tracking, and SIEM integration.

---

### Getting Help

- Check the [documentation](/docs/) for detailed guides
- Review [troubleshooting procedures](/docs/Admin-Features.md#troubleshooting)
- Consult the [monitoring dashboard](/docs/Monitoring.md#health-endpoints) for system status

### Contributing

- Follow the [development guidelines](/docs/Admin-Features.md#development-tools)
- Review [security requirements](/docs/DataPrivacy-GDPR.md#development-standards)
- Test with the [validation scripts](/docs/Admin-Features.md#validation-tools)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
