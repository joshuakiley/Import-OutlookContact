# Import and Data Management Features

This document details the advanced import capabilities, backup/restore functionality, duplicate management, and custom folder features of Import-OutlookContact.

## Overview

Import-OutlookContact supports multiple import formats and provides comprehensive data management capabilities including automatic backups, intelligent duplicate detection, and custom folder management for enterprise contact organization.

---

## Import Format Support

### Supported File Types

#### 1. vCard (.vcf) Import

- **Compatibility:** iPhone, Android, Mac, Outlook, most CRMs
- **Multi-contact Support:** Single file with multiple contacts
- **Auto-mapping:** Automatic field detection and mapping
- **Manual Override:** Custom field mapping capabilities

**Common vCard Sources:**

- iPhone/iOS Contacts export
- Android Contacts export
- Mac Contacts application
- Outlook Desktop/Web
- CRM system exports (Salesforce, HubSpot, etc.)

#### 2. Google Contacts CSV

- **Source:** Gmail, Google Workspace contact exports
- **Auto-detection:** Recognizes Google-specific column formats
- **Field Mapping:** Automatic mapping of Google fields to Outlook properties
- **Preview:** Edit contacts before import

#### 3. Outlook CSV Import

- **Formats Supported:**
  - Outlook Desktop CSV export
  - Outlook Web/Office 365 CSV
  - Windows CSV format
- **Field Recognition:** Automatic detection of Outlook field formats
- **Compatibility:** All Outlook versions and Office 365

#### 4. Generic CSV Import

- **Flexibility:** Any CSV file with headers
- **Custom Mapping:** User-defined field mapping
- **Mapping Profiles:** Save and reuse mapping configurations
- **Validation:** Real-time field validation during mapping

---

## Import Workflow

### Step-by-Step Process

1. **File Selection**

   ```powershell
   # Launch import wizard
   pwsh .\Import-OutlookContact.ps1 -Mode Import -WizardMode
   ```

2. **Format Detection**

   - Automatic file type detection
   - Format-specific parsing
   - Field structure analysis

3. **Field Mapping**

   - Auto-suggested mappings
   - Manual mapping override
   - Save mapping profiles
   - Validation rules

4. **Preview and Edit**

   - Tabular data preview
   - In-line editing capabilities
   - Add/remove contacts
   - Data validation

5. **Duplicate Detection**

   - Configurable matching criteria
   - Merge recommendations
   - Conflict resolution

6. **Import Execution**
   - Automatic backup creation
   - Progress tracking
   - Error handling
   - Success reporting

### Field Mapping Examples

#### vCard to Outlook Mapping

```json
{
  "vCardMappings": {
    "FN": "displayName",
    "N": "givenName,surname",
    "EMAIL": "emailAddresses[0].address",
    "TEL": "businessPhones[0]",
    "ORG": "companyName",
    "TITLE": "jobTitle",
    "ADR": "businessAddress"
  }
}
```

#### Google CSV Mapping

```json
{
  "googleMappings": {
    "Given Name": "givenName",
    "Family Name": "surname",
    "E-mail 1 - Value": "emailAddresses[0].address",
    "Phone 1 - Value": "businessPhones[0]",
    "Organization 1 - Name": "companyName",
    "Organization 1 - Title": "jobTitle"
  }
}
```

---

## Backup and Restore System

### Automatic Backup

#### Pre-Operation Backup

- **Trigger:** Before any contact modification
- **Scope:** All affected user contact folders
- **Encryption:** AES-256 encrypted backup files
- **Metadata:** Timestamp, user ID, operation type

```powershell
# Configure automatic backup policy
pwsh .\admin\Set-AutoBackupPolicy.ps1 -Enabled $true -RetentionDays 90 -EncryptionEnabled $true
```

#### Backup Storage Structure

```
\backups\
  \2024\
    \08\
      \04\
        \user@domain.com_20240804_143022_preimport.bak
        \user@domain.com_20240804_143022_preimport.metadata
```

### Manual Backup Operations

#### User-Initiated Backup

```powershell
# Backup specific user's contacts
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -BackupType "Full"

# Backup specific folders only
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -Folders @("Vendors", "Clients")

# Backup with custom retention
pwsh .\Backup-UserContacts.ps1 -UserEmail "user@domain.com" -RetentionDays 365
```

#### Bulk Backup Operations

```powershell
# Department-wide backup
pwsh .\admin\Backup-DepartmentContacts.ps1 -Department "HR" -BackupPath "\\backup\HR\"

# All users backup
pwsh .\admin\Backup-AllContacts.ps1 -BackupPath "\\backup\full\" -Parallel $true
```

### Restore Functionality

#### Restore with Preview

```powershell
# Preview restore operation
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -BackupDate "2024-08-04" -Preview

# Execute restore after preview
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -BackupDate "2024-08-04" -Confirm
```

#### Selective Restore

```powershell
# Restore specific folders only
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -BackupDate "2024-08-04" -Folders @("Vendors")

# Restore with conflict resolution
pwsh .\Restore-UserContacts.ps1 -UserEmail "user@domain.com" -BackupDate "2024-08-04" -ConflictAction "Merge"
```

#### Restore Conflict Resolution

- **Skip:** Leave existing contacts unchanged
- **Overwrite:** Replace existing contacts with backup data
- **Merge:** Combine contact information intelligently
- **Prompt:** Ask user for each conflict

---

## Duplicate Detection and Management

### Flexible Matching Criteria

#### Configurable Match Fields

```powershell
# Email-based duplicate detection (default)
pwsh .\Find-DuplicateContacts.ps1 -MatchCriteria "Email"

# Phone-based detection for contacts without email
pwsh .\Find-DuplicateContacts.ps1 -MatchCriteria "Phone"

# Combined email and phone matching
pwsh .\Find-DuplicateContacts.ps1 -MatchCriteria "EmailAndPhone"

# Custom field matching
pwsh .\Find-DuplicateContacts.ps1 -MatchCriteria "Custom" -CustomFields @("EmployeeId", "LastName")
```

### Handling Contacts Without Email

#### Fallback Matching Strategy

1. **Primary:** Email address matching
2. **Secondary:** Phone number matching
3. **Tertiary:** Name + company matching
4. **Custom:** User-defined field combinations

```powershell
# Configure fallback matching
pwsh .\admin\Set-DuplicateDetectionPolicy.ps1 -FallbackFields @("businessPhones[0]", "displayName", "companyName")
```

### Merge Operations

#### Automatic Merge Rules

```json
{
  "mergeRules": {
    "preferNewer": true,
    "keepAllPhones": true,
    "keepAllEmails": true,
    "mergeNotes": true,
    "preferNonEmpty": true
  }
}
```

#### Manual Merge Interface

- **Side-by-side Comparison:** View contact details
- **Field Selection:** Choose preferred values
- **Merge Preview:** See result before applying
- **Batch Operations:** Apply rules to all duplicates

#### Merge Reporting

```powershell
# Generate merge report
pwsh .\Get-MergeReport.ps1 -Operation "2024-08-04-143022" -Format "Excel"
```

**Report Contents:**

- Total duplicates found
- Merge actions taken
- Conflicts resolved
- Skipped contacts
- Error details

---

## Custom Folder Management

### Folder Types

#### Standard Organization Folders

- **Org1:** First organization contacts
- **Org2:** Second organization contacts
- **Org3:** Third organization contacts

#### Custom Business Folders

- **Vendors:** Supplier and vendor contacts
- **Contractors:** External contractor contacts
- **Clients:** Customer and client contacts
- **Partners:** Business partner contacts

### Folder Assignment

#### Department-Based Assignment

```powershell
# Assign folders by department
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "HR" -Folders @("Vendors", "Contractors")
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "Sales" -Folders @("Clients", "Partners")
pwsh .\admin\Set-DepartmentFolders.ps1 -Department "IT" -Folders @("Vendors", "Contractors")
```

#### Bulk Folder Assignment

```csv
# folder-assignments.csv
UserEmail,Department,Folders,CreatedBy,CreatedDate
alice@domain.com,HR,"Vendors,Contractors",admin@domain.com,2024-08-04
bob@domain.com,Sales,"Clients,Partners",admin@domain.com,2024-08-04
charlie@domain.com,IT,"Vendors",admin@domain.com,2024-08-04
```

```powershell
# Import bulk assignments
pwsh .\admin\Import-FolderAssignments.ps1 -CsvPath .\folder-assignments.csv -Preview
```

#### Individual Assignment

```powershell
# Create custom folder for specific user
pwsh .\admin\New-CustomContactFolder.ps1 -UserEmail "user@domain.com" -FolderName "Consultants"

# Assign multiple folders
pwsh .\admin\Set-UserFolders.ps1 -UserEmail "user@domain.com" -Folders @("Vendors", "Clients", "Consultants")
```

### Folder Management Operations

#### Contact Migration

```powershell
# Move contacts between folders
pwsh .\Move-ContactsBetweenFolders.ps1 -UserEmail "user@domain.com" -FromFolder "Org1" -ToFolder "Vendors"

# Bulk move with criteria
pwsh .\Move-ContactsBetweenFolders.ps1 -UserEmail "user@domain.com" -FromFolder "Org1" -ToFolder "Vendors" -Criteria "Company contains 'Supplier'"
```

#### Folder Cleanup

```powershell
# Remove empty custom folder
pwsh .\admin\Remove-EmptyFolder.ps1 -UserEmail "user@domain.com" -FolderName "OldFolder"

# Merge folder contents before removal
pwsh .\admin\Remove-CustomFolder.ps1 -UserEmail "user@domain.com" -FolderName "OldFolder" -MergeTo "Contractors"
```

---

## Error Handling and Validation

### Import Validation

#### Pre-Import Checks

- **File Format Validation:** Verify file structure and encoding
- **Field Validation:** Check required fields and data types
- **Data Integrity:** Validate email formats, phone numbers
- **Duplicate Pre-Check:** Identify potential duplicates before import

#### Error Categories

1. **Critical Errors:** Invalid file format, corrupted data
2. **Warnings:** Missing optional fields, formatting issues
3. **Information:** Duplicate notifications, mapping suggestions

### Backup Validation

#### Backup Integrity Checks

```powershell
# Verify backup file integrity
pwsh .\admin\Test-BackupIntegrity.ps1 -BackupPath "\\backup\user@domain.com_20240804.bak"

# Validate all backups
pwsh .\admin\Test-AllBackups.ps1 -BackupDirectory "\\backup\" -Detailed
```

#### Restore Validation

- **Data Consistency:** Verify restored data matches backup
- **Reference Integrity:** Check contact relationships
- **Folder Structure:** Validate folder hierarchy

---

## Performance Optimization

### Large Dataset Handling

#### Batch Processing

- **Import Batching:** Process large imports in chunks
- **Memory Management:** Efficient memory usage for large files
- **Progress Tracking:** Real-time progress indicators
- **Parallel Processing:** Multi-threaded operations where possible

#### Performance Tuning

```powershell
# Configure batch sizes for large imports
pwsh .\admin\Set-PerformanceConfig.ps1 -ImportBatchSize 500 -DuplicateScanBatchSize 1000

# Enable parallel processing
pwsh .\admin\Set-PerformanceConfig.ps1 -ParallelProcessing $true -MaxThreads 4
```

### Monitoring and Metrics

#### Performance Metrics

- Import speed (contacts per minute)
- Memory usage during operations
- Backup/restore times
- Duplicate detection efficiency

#### Optimization Recommendations

- Optimal batch sizes for different operations
- Memory requirements for large datasets
- Network considerations for backup storage
- Concurrent operation limitations

---

## Security Considerations

### Data Protection

#### Encryption

- **In-Transit:** TLS encryption for all API communications
- **At-Rest:** AES-256 encryption for backup files
- **Key Management:** Secure key storage and rotation

#### Access Controls

- **Role-Based Access:** Different permissions for users and admins
- **Audit Logging:** Complete audit trail for all operations
- **Data Classification:** Automatic PII detection and handling

### Compliance Features

#### GDPR Compliance

- **Data Minimization:** Import only necessary fields
- **Right to be Forgotten:** Complete data removal capabilities
- **Data Portability:** Export data in standard formats
- **Consent Management:** Track and manage data processing consent

#### Audit Requirements

- **Complete Audit Trail:** All import, backup, and restore operations logged
- **Immutable Logs:** Tamper-proof audit records
- **Compliance Reporting:** Pre-built reports for various regulations
- **Data Retention:** Configurable retention policies

---

This comprehensive import and data management system provides enterprise-grade capabilities while maintaining ease of use and security compliance.
