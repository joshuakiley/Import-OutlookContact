# Enhanced vCard Import Support

The Import-OutlookContact project now includes comprehensive enhanced vCard (.vcf) import capabilities with advanced parsing, multiple format support, and intelligent duplicate handling.

## Overview

Enhanced vCard import provides:

- **Advanced Field Parsing** - Support for all standard vCard fields plus custom extensions
- **Multiple vCard Versions** - Support for vCard 2.1 and 3.0 formats
- **Intelligent Duplicate Handling** - Skip, Merge, Overwrite, or Consolidate duplicates
- **Multi-Value Field Support** - Multiple emails, phones, addresses, and URLs
- **Custom Field Extraction** - Handles X- fields and unrecognized properties
- **Enhanced Validation** - Comprehensive validation with detailed error reporting

## Key Features

### 🃏 Enhanced vCard Parsing

The enhanced parser (`Import-VCardContactsEnhanced`) provides better field extraction compared to the standard parser:

| Feature           | Standard Parser           | Enhanced Parser                                  |
| ----------------- | ------------------------- | ------------------------------------------------ |
| Name components   | ✅ Basic (Given, Surname) | ✅ Full (Prefix, Given, Middle, Surname, Suffix) |
| Email addresses   | ✅ Single                 | ✅ Multiple with types (WORK, HOME, OTHER)       |
| Phone numbers     | ✅ Basic categorization   | ✅ Advanced (Business, Home, Mobile, Fax)        |
| Addresses         | ❌ Not supported          | ✅ Business, Home, Other with full components    |
| Dates             | ❌ Not supported          | ✅ Birthday, Anniversary                         |
| URLs              | ❌ Not supported          | ✅ Multiple website URLs                         |
| Custom fields     | ❌ Not supported          | ✅ X- fields and unrecognized properties         |
| Categories        | ❌ Not supported          | ✅ Contact categories/tags                       |
| Line continuation | ❌ Basic                  | ✅ Proper multi-line handling                    |

### 📞 Advanced Contact Fields

Enhanced parsing supports comprehensive contact information:

#### Name Information

- Display Name (FN)
- Structured Name (N): Surname;GivenName;MiddleName;Prefix;Suffix
- Name prefix (Mr., Dr., etc.)
- Name suffix (Jr., PhD, etc.)

#### Contact Methods

- Multiple email addresses with types (WORK, HOME, OTHER)
- Business phones (multiple)
- Home phones (multiple)
- Mobile/Cell phone
- Fax numbers
- Website URLs

#### Organization

- Company name
- Department (from ORG field)
- Job title

#### Addresses

- Business address (complete)
- Home address (complete)
- Other addresses
- Full address components: Street, City, State, Postal Code, Country

#### Personal Information

- Birthday (BDAY)
- Anniversary dates
- Personal notes
- Contact categories/tags

#### Custom Extensions

- X- prefixed custom fields
- Unrecognized vCard properties
- Custom metadata preservation

### 🔄 Duplicate Handling Options

Enhanced duplicate detection works across all contact folders with multiple resolution options:

#### Skip

- Skips importing contacts that already exist
- Keeps existing contact data unchanged
- Shows which folder contains the duplicate

#### Merge (Interactive)

- Provides field-by-field merge control
- Shows detailed comparison between existing and new data
- Allows selective field updates
- Combines phone numbers and email addresses

#### Overwrite

- Completely replaces existing contact with new data
- Requires confirmation for safety
- Preserves contact ID and folder location

#### Consolidate (New!)

- Merges duplicate contacts into target folder
- Removes original contact from other folders
- Combines data from both contacts intelligently
- Perfect for organizing scattered contacts

### 🎯 Smart Folder Placement

The enhanced import can automatically place contacts in appropriate folders based on:

- Company name matching
- Custom folder mapping rules
- Department-based organization
- Default folder fallback

## Usage Examples

### Basic Enhanced Import

```powershell
# Import with enhanced parsing
Import-VCardContacts -FilePath ".\contacts.vcf" -UserEmail "user@domain.com" -EnhancedParsing $true
```

### Advanced Import with Consolidation

```powershell
# Import iPhone contacts and consolidate duplicates
Import-VCardContacts -FilePath ".\iphone-export.vcf" -UserEmail "user@domain.com" -ContactFolder "Personal" -DuplicateAction "Consolidate" -EnhancedParsing $true
```

### Validation Only

```powershell
# Validate vCard file without importing
Import-VCardContacts -FilePath ".\contacts.vcf" -UserEmail "user@domain.com" -ValidateOnly $true
```

### Folder-Based Import

```powershell
# Import business contacts to specific folder
Import-VCardContacts -FilePath ".\business-cards.vcf" -UserEmail "user@domain.com" -ContactFolder "Vendors" -DuplicateAction "Merge"
```

## Supported vCard Sources

The enhanced import works with vCard files from:

### Mobile Devices

- **iPhone/iOS** - Full contact export via iCloud or AirDrop
- **Android** - Google Contacts export
- **Windows Phone** - Contact backup files

### Email Platforms

- **Gmail/Google Workspace** - Contact export
- **Outlook Desktop/Web** - Contact export
- **Yahoo Mail** - Contact export
- **Apple iCloud** - Contact sync files

### CRM Systems

- **Salesforce** - Contact export
- **HubSpot** - Contact data export
- **Zoho CRM** - vCard export
- **Pipedrive** - Contact export

### Contact Management

- **Mac Contacts** - Export to vCard
- **Windows Contacts** - vCard export
- **CardDAV servers** - Contact sync
- **Generic vCard files** - Any RFC-compliant vCard

## File Format Support

### vCard Versions

- **vCard 2.1** - Basic compatibility
- **vCard 3.0** - Full feature support (recommended)

### Encoding Support

- **UTF-8** - Full Unicode character support
- **ASCII** - Basic character set
- **Auto-detection** - Automatic encoding detection

### Line Endings

- **Windows** (CRLF)
- **Unix/Linux** (LF)
- **Mac Classic** (CR)
- **Mixed** - Automatic normalization

## Advanced Features

### Custom Field Mapping

The enhanced parser preserves custom fields for future use:

```powershell
# Access custom fields
$contact = Import-VCardContactsEnhanced -FilePath "contacts.vcf" | Select-Object -First 1
$contact.CustomFields  # Contains X- fields and unrecognized properties
```

### Enhanced Validation

Get detailed validation results:

```powershell
$contacts = Import-VCardContactsEnhanced -FilePath "contacts.vcf"
$validation = Test-VCardContactsValidation -Contacts $contacts
# Shows validation errors, warnings, and suggestions
```

### Batch Processing

Process multiple vCard files:

```powershell
Get-ChildItem "*.vcf" | ForEach-Object {
    Import-VCardContacts -FilePath $_.FullName -UserEmail "user@domain.com" -ContactFolder "Imported"
}
```

## Integration with Existing Workflows

### CSV Import Enhancement

The vCard functionality integrates with the existing CSV import system:

```powershell
# Use enhanced import for mixed file types
$fileExtension = [System.IO.Path]::GetExtension($importFile).ToLower()
switch ($fileExtension) {
    ".csv" { Import-ContactsFromCSV -FilePath $importFile }
    ".vcf" { Import-VCardContactsEnhanced -FilePath $importFile }
}
```

### Backup and Restore

Enhanced vCard support works with the backup system:

```powershell
# Backup contacts as vCard
Backup-UserContacts -UserEmail "user@domain.com" -BackupFormat "vCard"

# Restore from vCard backup
Restore-UserContacts -UserEmail "user@domain.com" -BackupPath "backup.vcf"
```

## Performance Considerations

### Large Files

- Processes large vCard files efficiently
- Memory-conscious parsing for files with 1000+ contacts
- Progress reporting for long operations

### Batch Operations

- Optimized for bulk contact import
- Efficient duplicate detection across folders
- Minimal API calls through batching

### Error Handling

- Graceful handling of malformed vCard data
- Detailed error reporting for troubleshooting
- Continues processing despite individual contact errors

## Troubleshooting

### Common Issues

#### Parsing Errors

```
Problem: "vCard file is empty or unreadable"
Solution: Check file encoding (should be UTF-8) and verify file isn't corrupted
```

#### Missing Fields

```
Problem: Some contact fields not imported
Solution: Use enhanced parsing (-EnhancedParsing $true) for better field extraction
```

#### Duplicate Detection

```
Problem: Duplicates not detected properly
Solution: Ensure contacts have email addresses for matching
```

#### Authentication Issues

```
Problem: "Microsoft Graph authentication required"
Solution: Run Initialize-GraphAuthenticationAuto before importing
```

### Debug Information

Enable verbose logging for troubleshooting:

```powershell
Import-VCardContacts -FilePath "contacts.vcf" -UserEmail "user@domain.com" -Verbose
```

## API Reference

### Main Functions

#### Import-VCardContacts

Primary function for vCard import with all enhanced features.

**Parameters:**

- `FilePath` - Path to vCard file
- `UserEmail` - Target user's email address
- `ContactFolder` - Target folder name (default: "Contacts")
- `DuplicateAction` - Skip, Merge, Overwrite, Consolidate (default: "Merge")
- `EnhancedParsing` - Use enhanced parsing (default: true)
- `ValidateOnly` - Validation only mode (default: false)

#### Import-VCardContactsEnhanced

Enhanced vCard parsing function.

**Parameters:**

- `FilePath` - Path to vCard file

**Returns:** Array of enhanced contact objects

#### Convert-VCardToContactEnhanced

Converts individual vCard text to enhanced contact object.

**Parameters:**

- `VCardText` - vCard text content

#### Test-VCardContactsValidation

Enhanced validation for vCard contacts.

**Parameters:**

- `Contacts` - Array of contact objects

### Helper Functions

#### Convert-VCardToGraphContact

Converts enhanced vCard contact to Microsoft Graph format.

#### Merge-VCardContactData

Merges contact data for consolidation operations.

#### Remove-ExistingContact

Removes existing contact during consolidation.

## Configuration

### Default Settings

The enhanced vCard import uses these default settings:

```json
{
  "EnhancedParsing": true,
  "DuplicateAction": "Merge",
  "ContactFolder": "Contacts",
  "ValidateOnly": false,
  "InteractiveMode": true,
  "CreateFolders": true
}
```

### Customization

Customize behavior through parameters or configuration files:

```powershell
# Custom company-to-folder mapping
$folderMapping = @{
    "Acme Corp" = "Vendors"
    "TechFlow" = "Partners"
    "Internal" = "Employees"
}

# Use with enhanced import workflow
```

## Migration Guide

### From Standard vCard Import

1. **Update Scripts**: Replace `Import-ContactsFromVCard` with `Import-VCardContacts`
2. **Enable Enhanced Parsing**: Add `-EnhancedParsing $true` parameter
3. **Update Duplicate Handling**: Consider using "Consolidate" action
4. **Test Validation**: Use `-ValidateOnly $true` for testing

### From Other Contact Systems

1. **Export to vCard**: Export contacts from source system as vCard
2. **Validate Format**: Test with validation-only mode first
3. **Map Folders**: Define folder mapping for organization
4. **Import with Merge**: Use "Merge" or "Consolidate" for initial import

## Future Enhancements

Planned improvements for vCard support:

- **vCard 4.0 Support** - Latest vCard specification
- **Photo Import** - Contact photo handling
- **Sync Capabilities** - Two-way vCard synchronization
- **Advanced Matching** - Phone-based and name-based duplicate detection
- **Bulk Operations** - Multi-file and directory import
- **Format Conversion** - Convert between vCard versions

## Support

For issues with vCard import:

1. **Check Documentation** - Review this guide and API reference
2. **Enable Verbose Logging** - Use `-Verbose` parameter for detailed output
3. **Validate File** - Use validation-only mode to check file format
4. **Test Sample Data** - Try with known-good vCard files first
5. **Report Issues** - Submit issues with sample vCard data (anonymized)

---

_This enhanced vCard support is part of the Import-OutlookContact enterprise contact management system._
