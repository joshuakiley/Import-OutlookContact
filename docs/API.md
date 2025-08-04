# API and CLI Reference

This document provides comprehensive reference information for Import-OutlookContact's PowerShell commands, REST API endpoints, and plugin interfaces.

---

## PowerShell Commands

### Core Import Commands

#### Import-OutlookContact.ps1

Main application script with multiple operation modes.

**Syntax:**

```powershell
pwsh .\Import-OutlookContact.ps1
    -Mode <String>
    [-CsvPath <String>]
    [-UserEmail <String>]
    [-ContactFolder <String>]
    [-DuplicateAction <String>]
    [-MappingProfile <String>]
    [-BackupEnabled <Boolean>]
    [-ValidateOnly <Boolean>]
    [-Verbose]
    [-Debug]
```

**Parameters:**

| Parameter         | Type    | Required    | Description                                                        | Default    |
| ----------------- | ------- | ----------- | ------------------------------------------------------------------ | ---------- |
| `Mode`            | String  | Yes         | Operation mode: BulkAdd, OnboardUser, Edit, Backup, Restore, Merge | -          |
| `CsvPath`         | String  | Conditional | Path to CSV/vCard file (required for import modes)                 | -          |
| `UserEmail`       | String  | Yes         | Target user's email address                                        | -          |
| `ContactFolder`   | String  | No          | Target contact folder name                                         | "Contacts" |
| `DuplicateAction` | String  | No          | Duplicate handling: Skip, Merge, Overwrite                         | "Skip"     |
| `MappingProfile`  | String  | No          | Field mapping profile name                                         | "Default"  |
| `BackupEnabled`   | Boolean | No          | Create backup before operation                                     | $true      |
| `ValidateOnly`    | Boolean | No          | Validate file without importing                                    | $false     |

**Examples:**

```powershell
# Basic CSV import
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ".\contacts.csv" -UserEmail "user@domain.com"

# Import with custom folder and duplicate merging
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ".\vendors.csv" -UserEmail "user@domain.com" -ContactFolder "Vendors" -DuplicateAction "Merge"

# vCard import with validation only
pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath ".\contacts.vcf" -UserEmail "user@domain.com" -ValidateOnly $true

# Backup user contacts
pwsh .\Import-OutlookContact.ps1 -Mode Backup -UserEmail "user@domain.com"

# Restore from backup
pwsh .\Import-OutlookContact.ps1 -Mode Restore -UserEmail "user@domain.com" -BackupDate "2024-08-04"
```

**Return Values:**

```powershell
@{
    Success = $true/$false
    Message = "Operation result message"
    ImportedCount = 0
    SkippedCount = 0
    ErrorCount = 0
    DuplicatesFound = 0
    BackupPath = "Path to backup file"
    Duration = "00:02:30"
    Errors = @("Error messages")
}
```

---

### Backup and Restore Commands

#### Backup-UserContacts.ps1

Create backups of user contact data.

**Syntax:**

```powershell
pwsh .\Backup-UserContacts.ps1
    -UserEmail <String>
    [-BackupType <String>]
    [-IncludeFolders <String[]>]
    [-BackupPath <String>]
    [-Encrypt <Boolean>]
    [-RetentionDays <Int32>]
    [-Compress <Boolean>]
```

**Parameters:**

| Parameter        | Type     | Required | Description                                  | Default                  |
| ---------------- | -------- | -------- | -------------------------------------------- | ------------------------ |
| `UserEmail`      | String   | Yes      | User's email address                         | -                        |
| `BackupType`     | String   | No       | Backup type: Full, Incremental, Differential | "Full"                   |
| `IncludeFolders` | String[] | No       | Specific folders to backup                   | All folders              |
| `BackupPath`     | String   | No       | Custom backup location                       | Default backup directory |
| `Encrypt`        | Boolean  | No       | Enable encryption                            | $true                    |
| `RetentionDays`  | Int32    | No       | Backup retention period                      | 90                       |
| `Compress`       | Boolean  | No       | Compress backup file                         | $true                    |

**Examples:**

```powershell
# Full backup with default settings
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com"

# Backup specific folders only
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -IncludeFolders @("Vendors", "Clients")

# Backup with custom retention and location
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -RetentionDays 365 -BackupPath "\\backup\contacts\"

# Unencrypted backup for testing
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -Encrypt $false -BackupPath ".\temp-backup\"
```

#### Restore-UserContacts.ps1

Restore contacts from backup files.

**Syntax:**

```powershell
pwsh .\Restore-UserContacts.ps1
    -UserEmail <String>
    [-BackupDate <String>]
    [-BackupPath <String>]
    [-Folders <String[]>]
    [-ConflictAction <String>]
    [-Preview <Boolean>]
    [-Confirm <Boolean>]
```

**Parameters:**

| Parameter        | Type     | Required    | Description                                 | Default       |
| ---------------- | -------- | ----------- | ------------------------------------------- | ------------- |
| `UserEmail`      | String   | Yes         | Target user's email address                 | -             |
| `BackupDate`     | String   | Conditional | Backup date (YYYY-MM-DD)                    | Latest backup |
| `BackupPath`     | String   | No          | Custom backup file path                     | Auto-locate   |
| `Folders`        | String[] | No          | Specific folders to restore                 | All folders   |
| `ConflictAction` | String   | No          | Conflict resolution: Skip, Overwrite, Merge | "Skip"        |
| `Preview`        | Boolean  | No          | Preview restore without executing           | $false        |
| `Confirm`        | Boolean  | No          | Require confirmation before restore         | $true         |

**Examples:**

```powershell
# Preview restore from latest backup
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -Preview $true

# Restore specific date with confirmation
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -BackupDate "2024-08-04" -Confirm $true

# Selective folder restore
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -Folders @("Vendors") -ConflictAction "Merge"

# Emergency restore without confirmation
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -Confirm $false -ConflictAction "Overwrite"
```

---

### Duplicate Management Commands

#### Find-DuplicateContacts.ps1

Identify and analyze duplicate contacts.

**Syntax:**

```powershell
pwsh .\Find-DuplicateContacts.ps1
    -UserEmail <String>
    [-MatchCriteria <String>]
    [-CustomFields <String[]>]
    [-OutputPath <String>]
    [-ExportFormat <String>]
    [-AutoMerge <Boolean>]
```

**Parameters:**

| Parameter       | Type     | Required | Description                                          | Default |
| --------------- | -------- | -------- | ---------------------------------------------------- | ------- |
| `UserEmail`     | String   | Yes      | User's email address                                 | -       |
| `MatchCriteria` | String   | No       | Matching method: Email, Phone, EmailAndPhone, Custom | "Email" |
| `CustomFields`  | String[] | No       | Custom fields for matching                           | -       |
| `OutputPath`    | String   | No       | Export path for results                              | -       |
| `ExportFormat`  | String   | No       | Export format: CSV, Excel, JSON                      | "CSV"   |
| `AutoMerge`     | Boolean  | No       | Automatically merge obvious duplicates               | $false  |

**Examples:**

```powershell
# Find email-based duplicates
pwsh .\Find-DuplicateContacts.ps1 -UserEmail "user@domain.com" -MatchCriteria "Email"

# Find duplicates by phone number
pwsh .\Find-DuplicateContacts.ps1 -UserEmail "user@domain.com" -MatchCriteria "Phone"

# Custom field matching with export
pwsh .\Find-DuplicateContacts.ps1 -UserEmail "user@domain.com" -MatchCriteria "Custom" -CustomFields @("EmployeeId", "LastName") -OutputPath ".\duplicates.xlsx" -ExportFormat "Excel"

# Auto-merge simple duplicates
pwsh .\Find-DuplicateContacts.ps1 -UserEmail "user@domain.com" -AutoMerge $true
```

#### Merge-DuplicateContacts.ps1

Merge duplicate contacts with conflict resolution.

**Syntax:**

```powershell
pwsh .\Merge-DuplicateContacts.ps1
    -UserEmail <String>
    -DuplicateGroups <Object[]>
    [-MergeRules <Hashtable>]
    [-InteractiveMode <Boolean>]
    [-BackupFirst <Boolean>]
```

**Parameters:**

| Parameter         | Type      | Required | Description                    | Default       |
| ----------------- | --------- | -------- | ------------------------------ | ------------- |
| `UserEmail`       | String    | Yes      | User's email address           | -             |
| `DuplicateGroups` | Object[]  | Yes      | Groups of duplicate contacts   | -             |
| `MergeRules`      | Hashtable | No       | Custom merge rules             | Default rules |
| `InteractiveMode` | Boolean   | No       | Prompt for conflict resolution | $false        |
| `BackupFirst`     | Boolean   | No       | Create backup before merging   | $true         |

**Examples:**

```powershell
# Find duplicates and merge interactively
$duplicates = pwsh .\Find-DuplicateContacts.ps1 -UserEmail "user@domain.com"
pwsh .\Merge-DuplicateContacts.ps1 -UserEmail "user@domain.com" -DuplicateGroups $duplicates -InteractiveMode $true

# Automated merge with custom rules
$mergeRules = @{
    PreferNewer = $true
    KeepAllPhones = $true
    KeepAllEmails = $true
    MergeNotes = $true
}
pwsh .\Merge-DuplicateContacts.ps1 -UserEmail "user@domain.com" -DuplicateGroups $duplicates -MergeRules $mergeRules
```

---

### Folder Management Commands

#### New-ContactFolder.ps1

Create custom contact folders.

**Syntax:**

```powershell
pwsh .\New-ContactFolder.ps1
    -UserEmail <String>
    -FolderName <String>
    [-ParentFolder <String>]
    [-FolderType <String>]
    [-Description <String>]
```

**Parameters:**

| Parameter      | Type   | Required | Description                             | Default    |
| -------------- | ------ | -------- | --------------------------------------- | ---------- |
| `UserEmail`    | String | Yes      | User's email address                    | -          |
| `FolderName`   | String | Yes      | Name of new folder                      | -          |
| `ParentFolder` | String | No       | Parent folder name                      | "Contacts" |
| `FolderType`   | String | No       | Folder type: Business, Personal, Shared | "Business" |
| `Description`  | String | No       | Folder description                      | -          |

**Examples:**

```powershell
# Create business folder
pwsh .\New-ContactFolder.ps1 -UserEmail "user@domain.com" -FolderName "Vendors"

# Create subfolder with description
pwsh .\New-ContactFolder.ps1 -UserEmail "user@domain.com" -FolderName "IT Vendors" -ParentFolder "Vendors" -Description "Technology service providers"

# Create shared folder
pwsh .\New-ContactFolder.ps1 -UserEmail "user@domain.com" -FolderName "Department Contacts" -FolderType "Shared"
```

#### Move-ContactsToFolder.ps1

Move contacts between folders.

**Syntax:**

```powershell
pwsh .\Move-ContactsToFolder.ps1
    -UserEmail <String>
    -SourceFolder <String>
    -TargetFolder <String>
    [-ContactFilter <String>]
    [-MoveAll <Boolean>]
    [-CreateTargetFolder <Boolean>]
```

**Examples:**

```powershell
# Move all contacts from Org1 to Vendors
pwsh .\Move-ContactsToFolder.ps1 -UserEmail "user@domain.com" -SourceFolder "Org1" -TargetFolder "Vendors" -MoveAll $true

# Move contacts matching criteria
pwsh .\Move-ContactsToFolder.ps1 -UserEmail "user@domain.com" -SourceFolder "Contacts" -TargetFolder "Clients" -ContactFilter "Company contains 'Corp'"

# Move with auto-create target folder
pwsh .\Move-ContactsToFolder.ps1 -UserEmail "user@domain.com" -SourceFolder "Org2" -TargetFolder "Contractors" -CreateTargetFolder $true
```

---

### Administrative Commands

#### Set-DepartmentFolders.ps1

Configure folder assignments by department.

**Syntax:**

```powershell
pwsh .\admin\Set-DepartmentFolders.ps1
    -Department <String>
    -Folders <String[]>
    [-UserEmails <String[]>]
    [-CreateFolders <Boolean>]
    [-ApplyToExisting <Boolean>]
```

**Examples:**

```powershell
# Configure Sales department folders
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "Sales" -Folders @("Clients", "Prospects", "Partners")

# Apply to specific users
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "HR" -Folders @("Vendors", "Contractors") -UserEmails @("hr1@domain.com", "hr2@domain.com")

# Create folders if they don't exist
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "IT" -Folders @("Vendors", "Support") -CreateFolders $true
```

#### Test-SystemHealth.ps1

Perform comprehensive system health checks.

**Syntax:**

```powershell
pwsh .\admin\Test-SystemHealth.ps1
    [-Detailed <Boolean>]
    [-OutputPath <String>]
    [-ExportFormat <String>]
    [-IncludePerformance <Boolean>]
    [-TestConnectivity <Boolean>]
```

**Examples:**

```powershell
# Basic health check
pwsh .\admin\Test-SystemHealth.ps1

# Detailed health check with report
pwsh .\admin\Test-SystemHealth.ps1 -Detailed $true -OutputPath ".\health-report.html" -ExportFormat "HTML"

# Performance and connectivity testing
pwsh .\admin\Test-SystemHealth.ps1 -IncludePerformance $true -TestConnectivity $true
```

---

## REST API Endpoints

### Authentication

All API endpoints require Azure AD authentication with appropriate permissions.

**Authentication Header:**

```http
Authorization: Bearer <access_token>
```

**Required Permissions:**

- `Contacts.ReadWrite` - Contact operations
- `User.Read.All` - User information
- `Directory.Read.All` - Directory access (admin operations)

---

### Import Operations

#### POST /api/import/upload

Upload a file for import processing.

**Request:**

```http
POST /api/import/upload
Content-Type: multipart/form-data

{
  "file": <file_data>,
  "userEmail": "user@domain.com",
  "targetFolder": "Vendors",
  "duplicateAction": "Skip"
}
```

**Response:**

```json
{
  "uploadId": "12345678-1234-1234-1234-123456789012",
  "fileName": "contacts.csv",
  "fileSize": 1024000,
  "format": "CSV",
  "contactCount": 500,
  "validationStatus": "Success",
  "uploadTime": "2024-08-04T14:30:22Z"
}
```

#### POST /api/import/preview

Generate preview of import operation.

**Request:**

```http
POST /api/import/preview
Content-Type: application/json

{
  "uploadId": "12345678-1234-1234-1234-123456789012",
  "fieldMapping": {
    "firstName": "Given Name",
    "lastName": "Family Name",
    "email": "E-mail 1 - Value"
  },
  "previewCount": 10
}
```

**Response:**

```json
{
  "previewId": "87654321-4321-4321-4321-210987654321",
  "contacts": [
    {
      "firstName": "John",
      "lastName": "Doe",
      "email": "john.doe@example.com",
      "validationStatus": "Valid",
      "duplicateStatus": "None"
    }
  ],
  "totalContacts": 500,
  "validContacts": 485,
  "invalidContacts": 15,
  "duplicatesFound": 5
}
```

#### POST /api/import/execute

Execute the import operation.

**Request:**

```http
POST /api/import/execute
Content-Type: application/json

{
  "previewId": "87654321-4321-4321-4321-210987654321",
  "userEmail": "user@domain.com",
  "targetFolder": "Vendors",
  "duplicateAction": "Merge",
  "createBackup": true
}
```

**Response:**

```json
{
  "importId": "11111111-2222-3333-4444-555555555555",
  "status": "InProgress",
  "startTime": "2024-08-04T14:35:00Z",
  "estimatedCompletion": "2024-08-04T14:40:00Z"
}
```

#### GET /api/import/status/{importId}

Get import operation status.

**Response:**

```json
{
  "importId": "11111111-2222-3333-4444-555555555555",
  "status": "Completed",
  "progress": 100,
  "startTime": "2024-08-04T14:35:00Z",
  "completionTime": "2024-08-04T14:38:45Z",
  "results": {
    "totalContacts": 500,
    "imported": 485,
    "skipped": 10,
    "errors": 5,
    "duplicatesFound": 5,
    "duplicatesMerged": 3
  },
  "backupPath": "\\backup\\user@domain.com_20240804_143500.bak",
  "logPath": "\\logs\\import_11111111.log"
}
```

#### GET /api/import/history

Get import history for user or system.

**Query Parameters:**

- `userEmail` (optional) - Filter by user
- `startDate` (optional) - Start date filter
- `endDate` (optional) - End date filter
- `status` (optional) - Filter by status
- `limit` (optional) - Number of results (default: 50)

**Response:**

```json
{
  "imports": [
    {
      "importId": "11111111-2222-3333-4444-555555555555",
      "userEmail": "user@domain.com",
      "fileName": "contacts.csv",
      "status": "Completed",
      "importDate": "2024-08-04T14:35:00Z",
      "contactsImported": 485
    }
  ],
  "totalCount": 1,
  "hasMore": false
}
```

---

### Contact Management

#### GET /api/contacts/{userId}

Get contacts for a specific user.

**Query Parameters:**

- `folder` (optional) - Filter by folder
- `search` (optional) - Search term
- `limit` (optional) - Number of results
- `offset` (optional) - Pagination offset

**Response:**

```json
{
  "contacts": [
    {
      "id": "contact-id-123",
      "displayName": "John Doe",
      "emailAddresses": [
        {
          "address": "john.doe@example.com",
          "name": "Work"
        }
      ],
      "businessPhones": ["+1-555-123-4567"],
      "companyName": "Acme Corp",
      "jobTitle": "Manager",
      "folder": "Vendors"
    }
  ],
  "totalCount": 485,
  "hasMore": true
}
```

#### GET /api/contacts/{userId}/folders

Get contact folders for a user.

**Response:**

```json
{
  "folders": [
    {
      "id": "folder-id-123",
      "displayName": "Vendors",
      "contactCount": 150,
      "parentFolderId": "contacts-root",
      "created": "2024-08-01T10:00:00Z"
    },
    {
      "id": "folder-id-456",
      "displayName": "Clients",
      "contactCount": 200,
      "parentFolderId": "contacts-root",
      "created": "2024-08-01T10:00:00Z"
    }
  ]
}
```

#### POST /api/contacts/{userId}/folders

Create a new contact folder.

**Request:**

```http
POST /api/contacts/{userId}/folders
Content-Type: application/json

{
  "displayName": "Contractors",
  "parentFolderId": "contacts-root",
  "description": "External contractor contacts"
}
```

**Response:**

```json
{
  "id": "folder-id-789",
  "displayName": "Contractors",
  "contactCount": 0,
  "parentFolderId": "contacts-root",
  "created": "2024-08-04T14:45:00Z"
}
```

#### DELETE /api/contacts/{userId}/folders/{folderId}

Delete a contact folder.

**Query Parameters:**

- `moveContacts` (optional) - Target folder for contacts (default: delete contacts)

**Response:**

```json
{
  "success": true,
  "message": "Folder deleted successfully",
  "contactsAffected": 25,
  "contactsMovedTo": "Contacts"
}
```

---

### Backup Operations

#### POST /api/backup/{userId}

Create a backup for a user.

**Request:**

```http
POST /api/backup/{userId}
Content-Type: application/json

{
  "backupType": "Full",
  "includeFolders": ["Vendors", "Clients"],
  "encrypt": true,
  "compress": true,
  "retentionDays": 90
}
```

**Response:**

```json
{
  "backupId": "backup-12345",
  "backupPath": "\\backup\\user@domain.com_20240804_145000.bak",
  "status": "InProgress",
  "startTime": "2024-08-04T14:50:00Z",
  "estimatedCompletion": "2024-08-04T14:55:00Z"
}
```

#### GET /api/backup/{userId}/list

List available backups for a user.

**Query Parameters:**

- `limit` (optional) - Number of results
- `startDate` (optional) - Start date filter
- `endDate` (optional) - End date filter

**Response:**

```json
{
  "backups": [
    {
      "backupId": "backup-12345",
      "backupDate": "2024-08-04T14:50:00Z",
      "backupType": "Full",
      "contactCount": 485,
      "fileSize": 1024000,
      "encrypted": true,
      "status": "Completed"
    }
  ],
  "totalCount": 5
}
```

#### POST /api/restore/{userId}

Restore contacts from backup.

**Request:**

```http
POST /api/restore/{userId}
Content-Type: application/json

{
  "backupId": "backup-12345",
  "folders": ["Vendors"],
  "conflictAction": "Merge",
  "preview": false
}
```

**Response:**

```json
{
  "restoreId": "restore-67890",
  "status": "InProgress",
  "startTime": "2024-08-04T15:00:00Z",
  "estimatedCompletion": "2024-08-04T15:05:00Z"
}
```

#### GET /api/restore/status/{restoreId}

Get restore operation status.

**Response:**

```json
{
  "restoreId": "restore-67890",
  "status": "Completed",
  "progress": 100,
  "startTime": "2024-08-04T15:00:00Z",
  "completionTime": "2024-08-04T15:03:30Z",
  "results": {
    "contactsRestored": 150,
    "conflictsResolved": 5,
    "errors": 0
  }
}
```

---

### System Operations

#### GET /health

Basic health check endpoint.

**Response:**

```json
{
  "status": "Healthy",
  "timestamp": "2024-08-04T15:10:00Z",
  "version": "1.0.0"
}
```

#### GET /health/detailed

Comprehensive system status.

**Response:**

```json
{
  "status": "Healthy",
  "timestamp": "2024-08-04T15:10:00Z",
  "version": "1.0.0",
  "components": {
    "database": {
      "status": "Healthy",
      "responseTime": "15ms"
    },
    "graphApi": {
      "status": "Healthy",
      "responseTime": "125ms"
    },
    "storage": {
      "status": "Healthy",
      "freeSpace": "75%"
    }
  },
  "metrics": {
    "activeUsers": 25,
    "importsToday": 12,
    "systemLoad": "45%"
  }
}
```

#### GET /metrics

Performance metrics and statistics.

**Response:**

```json
{
  "timestamp": "2024-08-04T15:10:00Z",
  "metrics": {
    "requests": {
      "total": 1250,
      "successful": 1200,
      "failed": 50,
      "averageResponseTime": "250ms"
    },
    "imports": {
      "total": 45,
      "successful": 42,
      "failed": 3,
      "averageImportTime": "2m30s"
    },
    "system": {
      "cpuUsage": "45%",
      "memoryUsage": "60%",
      "diskUsage": "25%"
    }
  }
}
```

---

## Plugin Interface

### Plugin Architecture

Import-OutlookContact supports plugins for extending functionality:

#### Plugin Types

1. **Import Plugins** - Support for additional file formats
2. **Export Plugins** - Custom export formats and destinations
3. **Validation Plugins** - Custom data validation rules
4. **Integration Plugins** - Third-party system integrations
5. **UI Plugins** - Custom user interface components

#### Plugin Development

**Plugin Manifest (plugin.json):**

```json
{
  "name": "CustomCRMPlugin",
  "version": "1.0.0",
  "description": "Integration with Custom CRM system",
  "author": "Your Company",
  "type": "Integration",
  "entryPoint": "CustomCRMPlugin.ps1",
  "dependencies": ["CustomCRM.PowerShell"],
  "permissions": ["Contacts.ReadWrite", "ExternalSystem.Access"],
  "configuration": {
    "apiEndpoint": {
      "type": "string",
      "required": true,
      "description": "CRM API endpoint URL"
    },
    "apiKey": {
      "type": "string",
      "required": true,
      "secure": true,
      "description": "API authentication key"
    }
  }
}
```

**Plugin Implementation:**

```powershell
# CustomCRMPlugin.ps1

# Plugin initialization
function Initialize-Plugin {
    param(
        [hashtable]$Configuration
    )

    # Initialize plugin with configuration
    $script:ApiEndpoint = $Configuration.apiEndpoint
    $script:ApiKey = $Configuration.apiKey

    Write-Information "CustomCRM Plugin initialized"
}

# Export contacts to CRM
function Export-ContactsToCRM {
    param(
        [Object[]]$Contacts,
        [hashtable]$Options
    )

    try {
        foreach ($contact in $Contacts) {
            $crmContact = Convert-ToCustomCRMFormat -Contact $contact
            $result = Invoke-CustomCRMAPI -Method POST -Endpoint "/contacts" -Body $crmContact

            if ($result.Success) {
                Write-Information "Exported contact: $($contact.DisplayName)"
            }
            else {
                Write-Warning "Failed to export contact: $($contact.DisplayName)"
            }
        }

        return @{
            Success = $true
            ExportedCount = $Contacts.Count
        }
    }
    catch {
        Write-Error "Plugin error: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Plugin cleanup
function Cleanup-Plugin {
    # Cleanup resources
    Write-Information "CustomCRM Plugin cleanup completed"
}
```

#### Plugin Registration

```powershell
# Register plugin
pwsh .\admin\Register-Plugin.ps1 -PluginPath ".\plugins\CustomCRMPlugin\" -Enable $true

# List registered plugins
pwsh .\admin\Get-RegisteredPlugins.ps1

# Enable/disable plugin
pwsh .\admin\Set-PluginStatus.ps1 -PluginName "CustomCRMPlugin" -Enabled $false
```

---

## Error Handling

### Error Response Format

All API endpoints return consistent error responses:

```json
{
  "error": {
    "code": "InvalidRequest",
    "message": "The request is invalid",
    "details": [
      {
        "field": "userEmail",
        "message": "Invalid email format"
      }
    ],
    "requestId": "req-12345",
    "timestamp": "2024-08-04T15:15:00Z"
  }
}
```

### Error Codes

| Code                 | Description                     | HTTP Status |
| -------------------- | ------------------------------- | ----------- |
| `InvalidRequest`     | Request validation failed       | 400         |
| `Unauthorized`       | Authentication required         | 401         |
| `Forbidden`          | Insufficient permissions        | 403         |
| `NotFound`           | Resource not found              | 404         |
| `Conflict`           | Resource conflict               | 409         |
| `TooManyRequests`    | Rate limit exceeded             | 429         |
| `InternalError`      | Server error                    | 500         |
| `ServiceUnavailable` | Service temporarily unavailable | 503         |

### PowerShell Error Handling

```powershell
try {
    $result = Import-OutlookContact -Mode BulkAdd -CsvPath $csvPath -UserEmail $userEmail

    if ($result.Success) {
        Write-Host "Import completed successfully"
        Write-Host "Imported: $($result.ImportedCount) contacts"
    }
    else {
        Write-Error "Import failed: $($result.Message)"
        foreach ($error in $result.Errors) {
            Write-Warning $error
        }
    }
}
catch {
    Write-Error "Critical error: $($_.Exception.Message)"
    Write-Debug $_.Exception.StackTrace
}
```

---

## Rate Limits

### API Rate Limits

| Endpoint Category  | Requests per Minute | Burst Limit |
| ------------------ | ------------------- | ----------- |
| Import Operations  | 10                  | 20          |
| Contact Management | 60                  | 120         |
| Backup Operations  | 5                   | 10          |
| System Operations  | 30                  | 60          |

### Rate Limit Headers

```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1691164200
```

### Handling Rate Limits

```powershell
function Invoke-APIWithRetry {
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [int]$MaxRetries = 3
    )

    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            $response = Invoke-RestMethod -Uri $Uri -Headers $Headers
            return $response
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 429) {
                $retryAfter = $_.Exception.Response.Headers["Retry-After"]
                Write-Warning "Rate limit exceeded. Waiting $retryAfter seconds..."
                Start-Sleep -Seconds $retryAfter
            }
            else {
                throw
            }
        }
    }

    throw "Max retries exceeded"
}
```

---

This API reference provides comprehensive documentation for all available commands, endpoints, and interfaces in Import-OutlookContact. Regular updates ensure it remains current with new features and functionality.
