<#
.SYNOPSIS
    ContactOperations module for Import-OutlookContact
    
.DESCRIPTION
    Provides core contact management operations including backup, restore, import, and merge functionality
    for Microsoft Graph Contacts API integration.
    
.NOTES
    Version: 1.0.0
    Author: Import-OutlookContact Team
    Dependencies: Microsoft.Graph module, Authentication.psm1
#>

# Import required modules
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Backup user contacts to a specified location
    
.DESCRIPTION
    Creates a comprehensive backup of user contacts including metadata, custom fields,
    and folder organization. Supports multiple export formats.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER BackupPath
    Path where backup files will be stored
    
.PARAMETER BackupFormat
    Export format: JSON, vCard, CSV (default: JSON)
    
.PARAMETER IncludePhotos
    Include contact photos in backup (default: false)
    
.PARAMETER ContactFolder
    Specific contact folder to backup (default: all folders)
    
.EXAMPLE
    Backup-UserContacts -UserEmail "user@domain.com" -BackupPath ".\backups\"
    
.EXAMPLE
    Backup-UserContacts -UserEmail "user@domain.com" -BackupPath ".\backups\" -BackupFormat "vCard" -IncludePhotos $true
#>
function Backup-UserContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("JSON", "vCard", "CSV")]
        [string]$BackupFormat = "JSON",
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludePhotos = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$ContactFolder = ""
    )
    
    try {
        Write-Information "Starting backup operation for user: $UserEmail" -InformationAction Continue
        Write-Verbose "Backup parameters: Format=$BackupFormat, IncludePhotos=$IncludePhotos, Folder=$ContactFolder"
        
        # Validate authentication
        if (-not (Test-GraphConnection)) {
            throw "Microsoft Graph connection is not available. Please authenticate first."
        }
        
        # Validate required permissions
        if (-not (Test-RequiredPermissions -RequiredScopes @("Contacts.Read", "User.Read"))) {
            throw "Insufficient permissions for backup operation"
        }
        
        # Create backup directory structure
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $userBackupPath = Join-Path $BackupPath "$($UserEmail.Replace('@', '_'))_$timestamp"
        
        if (-not (Test-Path $userBackupPath)) {
            New-Item -Path $userBackupPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created backup directory: $userBackupPath"
        }
        
        # Initialize backup metadata
        $backupMetadata = @{
            UserEmail      = $UserEmail
            BackupDate     = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            BackupFormat   = $BackupFormat
            IncludePhotos  = $IncludePhotos
            ContactFolder  = $ContactFolder
            Version        = "1.0.0"
            TotalContacts  = 0
            ContactFolders = @()
            BackupFiles    = @()
        }
        
        # Get user's contact folders
        Write-Information "Retrieving contact folders..." -InformationAction Continue
        $contactFolders = Get-UserContactFolders -UserEmail $UserEmail
        
        if ($contactFolders.Count -eq 0) {
            Write-Warning "No contact folders found for user: $UserEmail"
            return @{
                Success      = $false
                Message      = "No contact folders found"
                BackupPath   = $userBackupPath
                ContactCount = 0
            }
        }
        
        $backupMetadata.ContactFolders = $contactFolders | ForEach-Object { 
            @{ Id = $_.Id; DisplayName = $_.DisplayName; TotalItems = $_.TotalItems } 
        }
        
        # Filter folders if specific folder requested
        if (-not [string]::IsNullOrEmpty($ContactFolder)) {
            $contactFolders = $contactFolders | Where-Object { $_.DisplayName -eq $ContactFolder }
            if ($contactFolders.Count -eq 0) {
                throw "Contact folder '$ContactFolder' not found for user: $UserEmail"
            }
            Write-Information "Backing up specific folder: $ContactFolder" -InformationAction Continue
        }
        else {
            Write-Information "Backing up all contact folders ($($contactFolders.Count) folders)" -InformationAction Continue
        }
        
        $totalContactsBackedUp = 0
        
        # Backup contacts from each folder
        foreach ($folder in $contactFolders) {
            Write-Information "Processing folder: $($folder.DisplayName)" -InformationAction Continue
            
            try {
                # Get contacts from folder
                $contacts = Get-ContactsFromFolder -UserEmail $UserEmail -FolderId $folder.Id -IncludePhotos $IncludePhotos
                
                if ($contacts.Count -gt 0) {
                    Write-Information "Found $($contacts.Count) contacts in folder: $($folder.DisplayName)" -InformationAction Continue
                    
                    # Create folder-specific backup file
                    $folderName = $folder.DisplayName -replace '[^\w\-_\.]', '_'
                    $backupFileName = "$folderName-contacts.$($BackupFormat.ToLower())"
                    $backupFilePath = Join-Path $userBackupPath $backupFileName
                    
                    # Export contacts in specified format
                    switch ($BackupFormat) {
                        "JSON" {
                            $contacts | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFilePath -Encoding UTF8
                        }
                        "vCard" {
                            Export-ContactsToVCard -Contacts $contacts -OutputPath $backupFilePath
                        }
                        "CSV" {
                            Export-ContactsToCSV -Contacts $contacts -OutputPath $backupFilePath
                        }
                    }
                    
                    $totalContactsBackedUp += $contacts.Count
                    $backupMetadata.BackupFiles += @{
                        FileName     = $backupFileName
                        FolderName   = $folder.DisplayName
                        ContactCount = $contacts.Count
                        FileSize     = (Get-Item $backupFilePath).Length
                    }
                    
                    Write-Information "✅ Backed up $($contacts.Count) contacts from '$($folder.DisplayName)'" -InformationAction Continue
                }
                else {
                    Write-Information "No contacts found in folder: $($folder.DisplayName)" -InformationAction Continue
                }
            }
            catch {
                Write-Error "Failed to backup folder '$($folder.DisplayName)': $($_.Exception.Message)"
                continue
            }
        }
        
        # Save backup metadata
        $backupMetadata.TotalContacts = $totalContactsBackedUp
        $metadataPath = Join-Path $userBackupPath "backup-metadata.json"
        $backupMetadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataPath -Encoding UTF8
        
        # Create backup summary
        $summaryPath = Join-Path $userBackupPath "backup-summary.txt"
        $summary = @"
Import-OutlookContact Backup Summary
===================================

User: $UserEmail
Backup Date: $($backupMetadata.BackupDate)
Backup Format: $BackupFormat
Total Contacts: $totalContactsBackedUp
Contact Folders: $($contactFolders.Count)

Folder Details:
$(($backupMetadata.BackupFiles | ForEach-Object { "- $($_.FolderName): $($_.ContactCount) contacts ($($_.FileName))" }) -join "`n")

Backup Location: $userBackupPath
"@
        $summary | Out-File -FilePath $summaryPath -Encoding UTF8
        
        Write-Information "" -InformationAction Continue
        Write-Information "🎉 Backup completed successfully!" -InformationAction Continue
        Write-Information "Total contacts backed up: $totalContactsBackedUp" -InformationAction Continue
        Write-Information "Backup location: $userBackupPath" -InformationAction Continue
        
        return @{
            Success      = $true
            Message      = "Backup completed successfully"
            BackupPath   = $userBackupPath
            ContactCount = $totalContactsBackedUp
            FolderCount  = $contactFolders.Count
            BackupFiles  = $backupMetadata.BackupFiles
        }
        
    }
    catch {
        $errorMessage = "Backup operation failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        return @{
            Success      = $false
            Message      = $errorMessage
            BackupPath   = $userBackupPath
            ContactCount = 0
        }
    }
}

<#
.SYNOPSIS
    Get user's contact folders
    
.DESCRIPTION
    Retrieves all contact folders for a specified user from Microsoft Graph.
    
.PARAMETER UserEmail
    Target user's email address
    
.EXAMPLE
    Get-UserContactFolders -UserEmail "user@domain.com"
#>
function Get-UserContactFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail
    )
    
    try {
        Write-Verbose "Retrieving contact folders for user: $UserEmail"
        
        # Import Microsoft Graph Users module if available
        if (Get-Module -ListAvailable -Name "Microsoft.Graph.PersonalContacts") {
            Import-Module Microsoft.Graph.PersonalContacts -Force -Verbose:$false
            
            # Get contact folders using Graph API
            $folders = Get-MgUserContactFolder -UserId $UserEmail -All
            
            if ($folders) {
                Write-Verbose "Found $($folders.Count) contact folders for user: $UserEmail"
                return $folders
            }
            else {
                Write-Warning "No contact folders found for user: $UserEmail"
                return @()
            }
        }
        else {
            # Fallback: Use REST API directly
            Write-Verbose "Microsoft.Graph.PersonalContacts not available, using REST API"
            
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contactFolders"
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            
            if ($response.value) {
                Write-Verbose "Found $($response.value.Count) contact folders via REST API"
                return $response.value
            }
            else {
                return @()
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve contact folders: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Get contacts from a specific folder
    
.DESCRIPTION
    Retrieves all contacts from a specified contact folder, with optional photo inclusion.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER FolderId
    Contact folder ID
    
.PARAMETER IncludePhotos
    Include contact photos (default: false)
    
.EXAMPLE
    Get-ContactsFromFolder -UserEmail "user@domain.com" -FolderId "folder-id"
#>
function Get-ContactsFromFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$FolderId,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludePhotos = $false
    )
    
    try {
        Write-Verbose "Retrieving contacts from folder: $FolderId"
        
        # Import Microsoft Graph PersonalContacts module if available
        if (Get-Module -ListAvailable -Name "Microsoft.Graph.PersonalContacts") {
            Import-Module Microsoft.Graph.PersonalContacts -Force -Verbose:$false
            
            # Get contacts from folder
            $contacts = Get-MgUserContactFolderContact -UserId $UserEmail -ContactFolderId $FolderId -All
            
            if ($IncludePhotos -and $contacts) {
                Write-Verbose "Including contact photos..."
                foreach ($contact in $contacts) {
                    try {
                        $photo = Get-MgUserContactPhoto -UserId $UserEmail -ContactId $contact.Id
                        if ($photo) {
                            $contact | Add-Member -NotePropertyName "PhotoData" -NotePropertyValue $photo
                        }
                    }
                    catch {
                        Write-Verbose "No photo available for contact: $($contact.DisplayName)"
                    }
                }
            }
            
            return $contacts
        }
        else {
            # Fallback: Use REST API directly
            Write-Verbose "Using REST API to retrieve contacts"
            
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contactFolders/$FolderId/contacts"
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            
            $contacts = $response.value
            
            # Handle photo inclusion via REST API
            if ($IncludePhotos -and $contacts) {
                foreach ($contact in $contacts) {
                    try {
                        $photoUri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contacts/$($contact.id)/photo/`$value"
                        $photoData = Invoke-MgGraphRequest -Uri $photoUri -Method GET
                        $contact | Add-Member -NotePropertyName "PhotoData" -NotePropertyValue $photoData
                    }
                    catch {
                        Write-Verbose "No photo available for contact: $($contact.displayName)"
                    }
                }
            }
            
            return $contacts
        }
    }
    catch {
        Write-Error "Failed to retrieve contacts from folder: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Export contacts to vCard format
    
.DESCRIPTION
    Converts contact objects to vCard format and saves to file.
    
.PARAMETER Contacts
    Array of contact objects
    
.PARAMETER OutputPath
    Output file path for vCard file
    
.EXAMPLE
    Export-ContactsToVCard -Contacts $contacts -OutputPath ".\contacts.vcf"
#>
function Export-ContactsToVCard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Contacts,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        Write-Verbose "Exporting $($Contacts.Count) contacts to vCard format"
        
        $vCardContent = @()
        
        foreach ($contact in $Contacts) {
            $vCard = @"
BEGIN:VCARD
VERSION:3.0
FN:$($contact.DisplayName)
N:$($contact.Surname);$($contact.GivenName);$($contact.MiddleName);;
EMAIL:$($contact.EmailAddresses[0].Address)
TEL:$($contact.HomePhones[0])
TEL;TYPE=WORK:$($contact.BusinessPhones[0])
TEL;TYPE=CELL:$($contact.MobilePhone)
ORG:$($contact.CompanyName)
TITLE:$($contact.JobTitle)
ADR;TYPE=HOME:;;$($contact.HomeAddress.Street);$($contact.HomeAddress.City);$($contact.HomeAddress.State);$($contact.HomeAddress.PostalCode);$($contact.HomeAddress.CountryOrRegion)
ADR;TYPE=WORK:;;$($contact.BusinessAddress.Street);$($contact.BusinessAddress.City);$($contact.BusinessAddress.State);$($contact.BusinessAddress.PostalCode);$($contact.BusinessAddress.CountryOrRegion)
NOTE:$($contact.PersonalNotes)
END:VCARD

"@
            $vCardContent += $vCard
        }
        
        $vCardContent -join "" | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Verbose "vCard export completed: $OutputPath"
        
    }
    catch {
        Write-Error "Failed to export contacts to vCard: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Export contacts to CSV format
    
.DESCRIPTION
    Converts contact objects to CSV format and saves to file.
    
.PARAMETER Contacts
    Array of contact objects
    
.PARAMETER OutputPath
    Output file path for CSV file
    
.EXAMPLE
    Export-ContactsToCSV -Contacts $contacts -OutputPath ".\contacts.csv"
#>
function Export-ContactsToCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Contacts,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        Write-Verbose "Exporting $($Contacts.Count) contacts to CSV format"
        
        # Create standardized CSV structure
        $csvData = foreach ($contact in $Contacts) {
            [PSCustomObject]@{
                DisplayName          = $contact.DisplayName
                GivenName            = $contact.GivenName
                Surname              = $contact.Surname
                MiddleName           = $contact.MiddleName
                CompanyName          = $contact.CompanyName
                JobTitle             = $contact.JobTitle
                Department           = $contact.Department
                EmailAddress         = if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) { $contact.EmailAddresses[0].Address } else { "" }
                BusinessPhone        = if ($contact.BusinessPhones -and $contact.BusinessPhones.Count -gt 0) { $contact.BusinessPhones[0] } else { "" }
                HomePhone            = if ($contact.HomePhones -and $contact.HomePhones.Count -gt 0) { $contact.HomePhones[0] } else { "" }
                MobilePhone          = $contact.MobilePhone
                BusinessStreet       = if ($contact.BusinessAddress) { $contact.BusinessAddress.Street } else { "" }
                BusinessCity         = if ($contact.BusinessAddress) { $contact.BusinessAddress.City } else { "" }
                BusinessState        = if ($contact.BusinessAddress) { $contact.BusinessAddress.State } else { "" }
                BusinessPostalCode   = if ($contact.BusinessAddress) { $contact.BusinessAddress.PostalCode } else { "" }
                BusinessCountry      = if ($contact.BusinessAddress) { $contact.BusinessAddress.CountryOrRegion } else { "" }
                HomeStreet           = if ($contact.HomeAddress) { $contact.HomeAddress.Street } else { "" }
                HomeCity             = if ($contact.HomeAddress) { $contact.HomeAddress.City } else { "" }
                HomeState            = if ($contact.HomeAddress) { $contact.HomeAddress.State } else { "" }
                HomePostalCode       = if ($contact.HomeAddress) { $contact.HomeAddress.PostalCode } else { "" }
                HomeCountry          = if ($contact.HomeAddress) { $contact.HomeAddress.CountryOrRegion } else { "" }
                PersonalNotes        = $contact.PersonalNotes
                Birthday             = $contact.Birthday
                CreatedDateTime      = $contact.CreatedDateTime
                LastModifiedDateTime = $contact.LastModifiedDateTime
                Id                   = $contact.Id
            }
        }
        
        $csvData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Verbose "CSV export completed: $OutputPath"
        
    }
    catch {
        Write-Error "Failed to export contacts to CSV: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Restore contacts from backup files
    
.DESCRIPTION
    Restores contacts from Import-OutlookContact backup files with folder structure preservation,
    selective restore options, and conflict resolution.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER BackupPath
    Path to backup directory or specific backup file
    
.PARAMETER RestoreFolder
    Specific folder to restore (default: all folders)
    
.PARAMETER ConflictAction
    How to handle existing contacts: Skip, Merge, Overwrite (default: Skip)
    
.PARAMETER PreserveStructure
    Preserve original folder structure (default: true)
    
.PARAMETER ValidateOnly
    Only validate backup without restoring (default: false)
    
.EXAMPLE
    Restore-UserContacts -UserEmail "user@domain.com" -BackupPath ".\backups\user_domain_com_20241201-143022"
    
.EXAMPLE
    Restore-UserContacts -UserEmail "user@domain.com" -BackupPath ".\backups\user_domain_com_20241201-143022" -RestoreFolder "Vendors" -ConflictAction "Merge"
#>
function Restore-UserContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        
        [Parameter(Mandatory = $false)]
        [string]$RestoreFolder = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Skip", "Merge", "Overwrite")]
        [string]$ConflictAction = "Skip",
        
        [Parameter(Mandatory = $false)]
        [bool]$PreserveStructure = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ValidateOnly = $false
    )
    
    try {
        Write-Information "Starting restore operation for user: $UserEmail" -InformationAction Continue
        Write-Information "Backup source: $BackupPath" -InformationAction Continue
        Write-Information "Conflict action: $ConflictAction" -InformationAction Continue
        
        # Validate backup path exists
        if (-not (Test-Path $BackupPath)) {
            throw "Backup path not found: $BackupPath"
        }
        
        # Determine if BackupPath is a directory or file
        $isDirectory = (Get-Item $BackupPath).PSIsContainer
        
        if ($isDirectory) {
            # Look for backup metadata
            $metadataPath = Join-Path $BackupPath "backup-metadata.json"
            if (-not (Test-Path $metadataPath)) {
                throw "Backup metadata not found. This may not be a valid Import-OutlookContact backup directory."
            }
            
            # Load backup metadata
            $backupMetadata = Get-Content $metadataPath -Encoding UTF8 | ConvertFrom-Json
            Write-Information "Found backup from: $($backupMetadata.BackupDate)" -InformationAction Continue
            Write-Information "Original format: $($backupMetadata.BackupFormat)" -InformationAction Continue
            Write-Information "Total contacts in backup: $($backupMetadata.TotalContacts)" -InformationAction Continue
            
            # Get backup files
            $backupFiles = $backupMetadata.BackupFiles
            
            # Filter by specific folder if requested
            if (-not [string]::IsNullOrEmpty($RestoreFolder)) {
                $backupFiles = $backupFiles | Where-Object { $_.FolderName -eq $RestoreFolder }
                if ($backupFiles.Count -eq 0) {
                    throw "Folder '$RestoreFolder' not found in backup"
                }
                Write-Information "Restoring specific folder: $RestoreFolder" -InformationAction Continue
            }
        }
        else {
            # Single file restore
            $backupFiles = @(@{
                    FileName     = Split-Path $BackupPath -Leaf
                    FolderName   = "Contacts"
                    ContactCount = 0
                    FileSize     = (Get-Item $BackupPath).Length
                })
            $backupMetadata = @{
                BackupFormat  = [System.IO.Path]::GetExtension($BackupPath).TrimStart('.').ToUpper()
                TotalContacts = 0
            }
        }
        
        # Validate authentication if not validation-only
        if (-not $ValidateOnly) {
            if (-not (Test-GraphConnection)) {
                throw "Microsoft Graph connection is not available. Please authenticate first."
            }
            
            # Validate required permissions
            if (-not (Test-RequiredPermissions -RequiredScopes @("Contacts.ReadWrite", "User.Read"))) {
                throw "Insufficient permissions for restore operation"
            }
        }
        
        Write-Information "Processing $($backupFiles.Count) backup files..." -InformationAction Continue
        
        $restoreResults = @{
            ProcessedFiles   = 0
            TotalContacts    = 0
            SuccessCount     = 0
            FailureCount     = 0
            SkippedCount     = 0
            CreatedFolders   = @()
            RestoredContacts = @()
            Errors           = @()
        }
        
        # Process each backup file
        foreach ($backupFile in $backupFiles) {
            try {
                Write-Information "Processing: $($backupFile.FileName) ($($backupFile.ContactCount) contacts)" -InformationAction Continue
                
                # Determine full file path
                $backupFilePath = if ($isDirectory) {
                    Join-Path $BackupPath $backupFile.FileName
                }
                else {
                    $BackupPath
                }
                
                if (-not (Test-Path $backupFilePath)) {
                    Write-Warning "Backup file not found: $backupFilePath"
                    continue
                }
                
                # Load contacts from backup file
                $contacts = switch ($backupMetadata.BackupFormat) {
                    "JSON" {
                        Get-Content $backupFilePath -Encoding UTF8 | ConvertFrom-Json
                    }
                    "CSV" {
                        Import-ContactsFromCSV -FilePath $backupFilePath -MappingProfile "Default"
                    }
                    { $_ -in @("vCard", "VCF") } {
                        Import-ContactsFromVCard -FilePath $backupFilePath
                    }
                    default {
                        throw "Unsupported backup format: $($backupMetadata.BackupFormat)"
                    }
                }
                
                if (-not $contacts -or $contacts.Count -eq 0) {
                    Write-Warning "No contacts found in backup file: $($backupFile.FileName)"
                    continue
                }
                
                $restoreResults.TotalContacts += $contacts.Count
                
                # Validate contacts
                $validationResult = Test-ContactsValidation -Contacts $contacts
                Write-Information "Validation: $($validationResult.ValidCount) valid, $($validationResult.InvalidCount) invalid" -InformationAction Continue
                
                if ($ValidateOnly) {
                    continue
                }
                
                # Determine target folder
                $targetFolderName = if ($PreserveStructure) { $backupFile.FolderName } else { "Contacts" }
                
                # Get or create target folder
                $targetFolder = Get-OrCreateContactFolder -UserEmail $UserEmail -FolderName $targetFolderName
                
                if ($targetFolder.Id -notin $restoreResults.CreatedFolders) {
                    $restoreResults.CreatedFolders += $targetFolder.Id
                    Write-Information "Using folder: $targetFolderName" -InformationAction Continue
                }
                
                # Handle conflicts if requested
                $contactsToRestore = $validationResult.ValidContacts
                if ($ConflictAction -ne "Overwrite") {
                    # Use global duplicate detection for restore operations too
                    $conflictResult = Find-DuplicateContacts -UserEmail $UserEmail -FolderId $targetFolder.Id -NewContacts $contactsToRestore -GlobalSearch
                    
                    if ($conflictResult.DuplicateCount -gt 0) {
                        Write-Information "Found $($conflictResult.DuplicateCount) potential conflicts across all folders" -InformationAction Continue
                        
                        $contactsToRestore = switch ($ConflictAction) {
                            "Skip" {
                                Write-Information "Skipping $($conflictResult.DuplicateCount) conflicting contacts" -InformationAction Continue
                                $restoreResults.SkippedCount += $conflictResult.DuplicateCount
                                $conflictResult.UniqueContacts
                            }
                            "Merge" {
                                Write-Information "Merging $($conflictResult.DuplicateCount) conflicting contacts" -InformationAction Continue
                                # For restore, merge means update existing with backup data
                                foreach ($existingContact in $conflictResult.ExistingContacts) {
                                    $matchingBackupContact = $conflictResult.DuplicateContacts | Where-Object { 
                                        $_.EmailAddresses[0].Address -eq $existingContact.EmailAddresses[0].Address 
                                    } | Select-Object -First 1
                                    
                                    if ($matchingBackupContact) {
                                        # Update existing contact with backup data
                                        Update-ExistingContact -UserEmail $UserEmail -ExistingContactId $existingContact.Id -BackupContact $matchingBackupContact
                                        $restoreResults.SuccessCount++
                                    }
                                }
                                $conflictResult.UniqueContacts
                            }
                        }
                    }
                }
                
                # Restore contacts
                foreach ($contact in $contactsToRestore) {
                    try {
                        $graphContact = Convert-ToGraphContact -Contact $contact
                        $createdContact = Add-ContactToFolder -UserEmail $UserEmail -FolderId $targetFolder.Id -Contact $graphContact
                        
                        $restoreResults.SuccessCount++
                        $restoreResults.RestoredContacts += $createdContact
                        
                        Write-Verbose "✅ Restored: $($contact.DisplayName)"
                    }
                    catch {
                        $restoreResults.FailureCount++
                        $restoreResults.Errors += @{
                            Contact = $contact.DisplayName
                            Error   = $_.Exception.Message
                            File    = $backupFile.FileName
                        }
                        Write-Warning "❌ Failed to restore: $($contact.DisplayName) - $($_.Exception.Message)"
                    }
                }
                
                $restoreResults.ProcessedFiles++
                
            }
            catch {
                Write-Error "Failed to process backup file '$($backupFile.FileName)': $($_.Exception.Message)"
                $restoreResults.Errors += @{
                    File  = $backupFile.FileName
                    Error = $_.Exception.Message
                }
                continue
            }
        }
        
        if ($ValidateOnly) {
            Write-Information "" -InformationAction Continue
            Write-Information "🔍 Validation completed!" -InformationAction Continue
            Write-Information "Total contacts in backup: $($restoreResults.TotalContacts)" -InformationAction Continue
            
            return @{
                Success        = $true
                Message        = "Validation completed successfully"
                TotalContacts  = $restoreResults.TotalContacts
                ValidContacts  = $restoreResults.TotalContacts
                ProcessedFiles = $restoreResults.ProcessedFiles
                ValidationOnly = $true
            }
        }
        
        Write-Information "" -InformationAction Continue
        Write-Information "🎉 Restore completed!" -InformationAction Continue
        Write-Information "Files processed: $($restoreResults.ProcessedFiles)" -InformationAction Continue
        Write-Information "Successfully restored: $($restoreResults.SuccessCount) contacts" -InformationAction Continue
        if ($restoreResults.SkippedCount -gt 0) {
            Write-Information "Skipped conflicts: $($restoreResults.SkippedCount) contacts" -InformationAction Continue
        }
        if ($restoreResults.FailureCount -gt 0) {
            Write-Information "Failed restores: $($restoreResults.FailureCount) contacts" -InformationAction Continue
        }
        
        return @{
            Success          = $true
            Message          = "Restore completed successfully"
            ProcessedFiles   = $restoreResults.ProcessedFiles
            TotalContacts    = $restoreResults.TotalContacts
            SuccessCount     = $restoreResults.SuccessCount
            FailureCount     = $restoreResults.FailureCount
            SkippedCount     = $restoreResults.SkippedCount
            CreatedFolders   = $restoreResults.CreatedFolders.Count
            RestoredContacts = $restoreResults.RestoredContacts
            Errors           = $restoreResults.Errors
        }
        
    }
    catch {
        $errorMessage = "Restore operation failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        return @{
            Success        = $false
            Message        = $errorMessage
            ProcessedFiles = 0
            SuccessCount   = 0
            FailureCount   = 0
        }
    }
}

<#
.SYNOPSIS
    Update existing contact with backup data
    
.DESCRIPTION
    Updates an existing Microsoft Graph contact with data from backup.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER ExistingContactId
    ID of existing contact to update
    
.PARAMETER BackupContact
    Contact data from backup to merge
    
.EXAMPLE
    Update-ExistingContact -UserEmail "user@domain.com" -ExistingContactId "contact-id" -BackupContact $backupContact
#>
function Update-ExistingContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$ExistingContactId,
        
        [Parameter(Mandatory = $true)]
        [PSObject]$BackupContact
    )
    
    try {
        Write-Verbose "Updating existing contact: $($BackupContact.DisplayName)"
        
        # Convert backup contact to Graph format
        $updateData = Convert-ToGraphContact -Contact $BackupContact
        
        if (Get-Module -ListAvailable -Name "Microsoft.Graph.PersonalContacts") {
            Import-Module Microsoft.Graph.PersonalContacts -Force -Verbose:$false
            
            # Update contact using Graph SDK
            Update-MgUserContact -UserId $UserEmail -ContactId $ExistingContactId -BodyParameter $updateData
        }
        else {
            # Use REST API
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contacts/$ExistingContactId"
            $body = $updateData | ConvertTo-Json -Depth 10
            Invoke-MgGraphRequest -Uri $uri -Method PATCH -Body $body
        }
        
        Write-Verbose "✅ Updated contact: $($BackupContact.DisplayName)"
    }
    catch {
        Write-Error "Failed to update existing contact: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Import contacts from CSV or vCard file
    
.DESCRIPTION
    Imports contacts from CSV or vCard files into specified contact folder with duplicate handling,
    field mapping, and validation.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER ImportFilePath
    Path to CSV or vCard file to import
    
.PARAMETER ContactFolder
    Target contact folder name (default: "Contacts")
    
.PARAMETER DuplicateAction
    How to handle duplicates: Skip, Merge, Overwrite (default: Skip)
    
.PARAMETER MappingProfile
    Field mapping profile name (default: "Default")
    
.PARAMETER ValidateOnly
    Only validate file without importing (default: false)
    
.EXAMPLE
    Import-UserContacts -UserEmail "user@domain.com" -ImportFilePath ".\contacts.csv"
    
.EXAMPLE
    Import-UserContacts -UserEmail "user@domain.com" -ImportFilePath ".\vendors.vcf" -ContactFolder "Vendors" -DuplicateAction "Merge"
#>
function Import-UserContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$ImportFilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$ContactFolder = "Contacts",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Skip", "Merge", "Overwrite")]
        [string]$DuplicateAction = "Skip",
        
        [Parameter(Mandatory = $false)]
        [string]$MappingProfile = "Default",
        
        [Parameter(Mandatory = $false)]
        [bool]$ValidateOnly = $false
    )
    
    try {
        Write-Information "Starting import operation for user: $UserEmail" -InformationAction Continue
        Write-Information "Import file: $ImportFilePath" -InformationAction Continue
        Write-Information "Target folder: $ContactFolder" -InformationAction Continue
        Write-Information "Duplicate action: $DuplicateAction" -InformationAction Continue
        
        # Validate file exists
        if (-not (Test-Path $ImportFilePath)) {
            throw "Import file not found: $ImportFilePath"
        }
        
        # Validate authentication
        if (-not $ValidateOnly) {
            if (-not (Test-GraphConnection)) {
                throw "Microsoft Graph connection is not available. Please authenticate first."
            }
            
            # Validate required permissions
            if (-not (Test-RequiredPermissions -RequiredScopes @("Contacts.ReadWrite", "User.Read"))) {
                throw "Insufficient permissions for import operation"
            }
        }
        
        # Detect file type and parse contacts
        $fileExtension = [System.IO.Path]::GetExtension($ImportFilePath).ToLower()
        Write-Information "Detected file type: $fileExtension" -InformationAction Continue
        
        $importedContacts = switch ($fileExtension) {
            ".csv" {
                Import-ContactsFromCSV -FilePath $ImportFilePath -MappingProfile $MappingProfile
            }
            ".vcf" {
                Import-ContactsFromVCard -FilePath $ImportFilePath
            }
            default {
                throw "Unsupported file format: $fileExtension. Supported formats: .csv, .vcf"
            }
        }
        
        if (-not $importedContacts -or $importedContacts.Count -eq 0) {
            throw "No valid contacts found in import file"
        }
        
        Write-Information "Found $($importedContacts.Count) contacts in import file" -InformationAction Continue
        
        # Validate contacts
        $validationResult = Test-ContactsValidation -Contacts $importedContacts
        Write-Information "Validation: $($validationResult.ValidCount) valid, $($validationResult.InvalidCount) invalid" -InformationAction Continue
        
        if ($validationResult.InvalidCount -gt 0) {
            Write-Warning "Found $($validationResult.InvalidCount) invalid contacts. Details:"
            foreach ($item in $validationResult.ValidationErrors) {
                Write-Warning "  - $($item.ContactIndex): $($item.ErrorMessage)"
            }
        }
        
        if ($ValidateOnly) {
            return @{
                Success          = $true
                Message          = "Validation completed"
                TotalContacts    = $importedContacts.Count
                ValidContacts    = $validationResult.ValidCount
                InvalidContacts  = $validationResult.InvalidCount
                ValidationErrors = $validationResult.ValidationErrors
            }
        }
        
        # Get or create target folder
        $targetFolder = Get-OrCreateContactFolder -UserEmail $UserEmail -FolderName $ContactFolder
        Write-Information "Target folder ID: $($targetFolder.Id)" -InformationAction Continue
        
        # Handle duplicates if requested
        $contactsToImport = $validationResult.ValidContacts
        if ($DuplicateAction -ne "Overwrite") {
            # Use global duplicate detection to check across ALL folders, not just target folder
            Write-Verbose "Checking for duplicates across all contact folders..."
            $duplicateResult = Find-DuplicateContacts -UserEmail $UserEmail -FolderId $targetFolder.Id -NewContacts $contactsToImport -GlobalSearch
            
            if ($duplicateResult.DuplicateCount -gt 0) {
                Write-Information "Found $($duplicateResult.DuplicateCount) potential duplicates across all folders" -InformationAction Continue
                
                # Show details about where duplicates were found
                foreach ($existingContact in $duplicateResult.ExistingContacts) {
                    if ($existingContact.SourceFolderName) {
                        Write-Information "  - Duplicate found in folder: $($existingContact.SourceFolderName)" -InformationAction Continue
                    }
                }
                
                $contactsToImport = switch ($DuplicateAction) {
                    "Skip" {
                        Write-Information "Skipping $($duplicateResult.DuplicateCount) duplicate contacts (found in other folders)" -InformationAction Continue
                        $duplicateResult.UniqueContacts
                    }
                    "Merge" {
                        Write-Information "Merging $($duplicateResult.DuplicateCount) duplicate contacts" -InformationAction Continue
                        
                        # Call the actual merge function with interactive prompts
                        $mergeResult = Merge-DuplicateContacts -ExistingContacts $duplicateResult.ExistingContacts -NewContacts $duplicateResult.DuplicateContacts -InteractiveMode $true
                        
                        # Combine unique contacts with successfully merged contacts
                        $contactsToImportAfterMerge = @()
                        $contactsToImportAfterMerge += $duplicateResult.UniqueContacts
                        $contactsToImportAfterMerge += $mergeResult.MergedContacts
                        
                        Write-Information "Merge results: $($mergeResult.MergedContacts.Count) will be imported, $($mergeResult.SkippedContacts.Count) skipped" -InformationAction Continue
                        
                        $contactsToImportAfterMerge
                    }
                }
            }
            else {
                Write-Information "No duplicates found across all folders" -InformationAction Continue
            }
        }
        
        Write-Information "Importing $($contactsToImport.Count) contacts..." -InformationAction Continue
        
        # Import contacts
        $importResults = @{
            SuccessCount     = 0
            FailureCount     = 0
            ImportedContacts = @()
            Errors           = @()
        }
        
        foreach ($contact in $contactsToImport) {
            try {
                $graphContact = Convert-ToGraphContact -Contact $contact
                $createdContact = Add-ContactToFolder -UserEmail $UserEmail -FolderId $targetFolder.Id -Contact $graphContact
                
                $importResults.SuccessCount++
                $importResults.ImportedContacts += $createdContact
                
                Write-Verbose "✅ Imported: $($contact.DisplayName)"
            }
            catch {
                $importResults.FailureCount++
                $importResults.Errors += @{
                    Contact = $contact.DisplayName
                    Error   = $_.Exception.Message
                }
                Write-Warning "❌ Failed to import: $($contact.DisplayName) - $($_.Exception.Message)"
            }
        }
        
        Write-Information "" -InformationAction Continue
        Write-Information "🎉 Import completed!" -InformationAction Continue
        Write-Information "Successfully imported: $($importResults.SuccessCount) contacts" -InformationAction Continue
        if ($importResults.FailureCount -gt 0) {
            Write-Information "Failed imports: $($importResults.FailureCount) contacts" -InformationAction Continue
        }
        
        return @{
            Success           = $true
            Message           = "Import completed successfully"
            TotalProcessed    = $importedContacts.Count
            SuccessCount      = $importResults.SuccessCount
            FailureCount      = $importResults.FailureCount
            SkippedDuplicates = if ($DuplicateAction -eq "Skip" -and $duplicateResult) { $duplicateResult.DuplicateCount } else { 0 }
            ImportedContacts  = $importResults.ImportedContacts
            Errors            = $importResults.Errors
        }
        
    }
    catch {
        $errorMessage = "Import operation failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        return @{
            Success        = $false
            Message        = $errorMessage
            TotalProcessed = 0
            SuccessCount   = 0
            FailureCount   = 0
        }
    }
}

<#
.SYNOPSIS
    Import contacts from CSV file
    
.DESCRIPTION
    Parses CSV file and converts to contact objects with field mapping support.
    
.PARAMETER FilePath
    Path to CSV file
    
.PARAMETER MappingProfile
    Field mapping profile name
    
.EXAMPLE
    Import-ContactsFromCSV -FilePath ".\contacts.csv" -MappingProfile "Default"
#>
function Import-ContactsFromCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$MappingProfile = "Default"
    )
    
    try {
        Write-Verbose "Importing contacts from CSV: $FilePath"
        
        # Import CSV data
        $csvData = Import-Csv -Path $FilePath -Encoding UTF8
        
        if (-not $csvData -or $csvData.Count -eq 0) {
            throw "No data found in CSV file"
        }
        
        Write-Verbose "Found $($csvData.Count) rows in CSV file"
        
        # Get field mapping for the profile
        $fieldMapping = Get-CSVFieldMapping -MappingProfile $MappingProfile -CSVHeaders ($csvData | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
        
        # Convert CSV rows to contact objects
        $contacts = foreach ($row in $csvData) {
            Convert-CSVRowToContact -CSVRow $row -FieldMapping $fieldMapping
        }
        
        Write-Verbose "Converted $($contacts.Count) CSV rows to contact objects"
        return $contacts
        
    }
    catch {
        Write-Error "Failed to import CSV file: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Import contacts from vCard file
    
.DESCRIPTION
    Parses vCard file and converts to contact objects.
    
.PARAMETER FilePath
    Path to vCard file
    
.EXAMPLE
    Import-ContactsFromVCard -FilePath ".\contacts.vcf"
#>
function Import-ContactsFromVCard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        Write-Verbose "Importing contacts from vCard: $FilePath"
        
        # Read vCard file content
        $vCardContent = Get-Content -Path $FilePath -Encoding UTF8 -Raw
        
        if ([string]::IsNullOrWhiteSpace($vCardContent)) {
            throw "vCard file is empty or unreadable"
        }
        
        # Split into individual vCards
        $vCards = $vCardContent -split "BEGIN:VCARD" | Where-Object { $_.Trim() -ne "" }
        
        Write-Verbose "Found $($vCards.Count) vCards in file"
        
        $contacts = foreach ($vCard in $vCards) {
            if ($vCard.Trim() -ne "") {
                Convert-VCardToContact -VCardText "BEGIN:VCARD$vCard"
            }
        }
        
        Write-Verbose "Converted $($contacts.Count) vCards to contact objects"
        return $contacts
        
    }
    catch {
        Write-Error "Failed to import vCard file: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Get CSV field mapping configuration
    
.DESCRIPTION
    Returns field mapping configuration for converting CSV columns to contact properties.
    
.PARAMETER MappingProfile
    Mapping profile name
    
.PARAMETER CSVHeaders
    Array of CSV column headers
    
.EXAMPLE
    Get-CSVFieldMapping -MappingProfile "Default" -CSVHeaders @("Name", "Email", "Phone")
#>
function Get-CSVFieldMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MappingProfile,
        
        [Parameter(Mandatory = $true)]
        [string[]]$CSVHeaders
    )
    
    # Default field mappings
    $defaultMapping = @{
        DisplayName        = @("DisplayName", "Name", "Full Name", "FullName", "Contact Name")
        GivenName          = @("GivenName", "FirstName", "First Name", "Given Name", "First")
        Surname            = @("Surname", "LastName", "Last Name", "Family Name", "Last")
        MiddleName         = @("MiddleName", "Middle Name", "Middle")
        CompanyName        = @("CompanyName", "Company", "Organization", "Org", "Business")
        JobTitle           = @("JobTitle", "Title", "Position", "Job Title", "Role")
        Department         = @("Department", "Dept", "Division")
        EmailAddress       = @("EmailAddress", "Email", "E-mail", "Email Address", "Primary Email")
        BusinessPhone      = @("BusinessPhone", "Business Phone", "Work Phone", "Office Phone", "Phone")
        HomePhone          = @("HomePhone", "Home Phone", "Personal Phone")
        MobilePhone        = @("MobilePhone", "Mobile", "Cell Phone", "Cell", "Cellular")
        BusinessStreet     = @("BusinessStreet", "Business Address", "Work Address", "Office Address", "Address")
        BusinessCity       = @("BusinessCity", "Business City", "Work City", "City")
        BusinessState      = @("BusinessState", "Business State", "Work State", "State")
        BusinessPostalCode = @("BusinessPostalCode", "Business ZIP", "Work ZIP", "ZIP", "Postal Code")
        BusinessCountry    = @("BusinessCountry", "Business Country", "Work Country", "Country")
        PersonalNotes      = @("PersonalNotes", "Notes", "Comments", "Description")
    }
    
    # Create mapping based on CSV headers
    $mapping = @{}
    
    foreach ($contactField in $defaultMapping.Keys) {
        $possibleHeaders = $defaultMapping[$contactField]
        $matchedHeader = $CSVHeaders | Where-Object { $_ -in $possibleHeaders } | Select-Object -First 1
        
        if ($matchedHeader) {
            $mapping[$contactField] = $matchedHeader
            Write-Verbose "Mapped '$matchedHeader' to $contactField"
        }
    }
    
    return $mapping
}

<#
.SYNOPSIS
    Convert CSV row to contact object
    
.DESCRIPTION
    Converts a CSV row to a standardized contact object using field mapping.
    
.PARAMETER CSVRow
    CSV row object
    
.PARAMETER FieldMapping
    Field mapping hashtable
    
.EXAMPLE
    Convert-CSVRowToContact -CSVRow $row -FieldMapping $mapping
#>
function Convert-CSVRowToContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$CSVRow,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$FieldMapping
    )
    
    $contact = [PSCustomObject]@{
        DisplayName     = ""
        GivenName       = ""
        Surname         = ""
        MiddleName      = ""
        CompanyName     = ""
        JobTitle        = ""
        Department      = ""
        EmailAddresses  = @()
        BusinessPhones  = @()
        HomePhones      = @()
        MobilePhone     = ""
        BusinessAddress = @{}
        HomeAddress     = @{}
        PersonalNotes   = ""
        Birthday        = $null
        Source          = "CSV Import"
    }
    
    # Map fields from CSV to contact
    foreach ($contactField in $FieldMapping.Keys) {
        $csvHeader = $FieldMapping[$contactField]
        $value = $CSVRow.$csvHeader
        
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            switch ($contactField) {
                "EmailAddress" {
                    $contact.EmailAddresses = @(@{ Address = $value.Trim() })
                }
                "BusinessPhone" {
                    $contact.BusinessPhones = @($value.Trim())
                }
                "HomePhone" {
                    $contact.HomePhones = @($value.Trim())
                }
                { $_ -like "Business*" -and $_ -ne "BusinessPhone" } {
                    $addressField = $_.Replace("Business", "")
                    if (-not $contact.BusinessAddress) { $contact.BusinessAddress = @{} }
                    $contact.BusinessAddress[$addressField] = $value.Trim()
                }
                default {
                    $contact.$contactField = $value.Trim()
                }
            }
        }
    }
    
    # Ensure DisplayName is populated
    if ([string]::IsNullOrWhiteSpace($contact.DisplayName)) {
        $nameParts = @($contact.GivenName, $contact.MiddleName, $contact.Surname) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($nameParts.Count -gt 0) {
            $contact.DisplayName = $nameParts -join " "
        }
    }
    
    return $contact
}

<#
.SYNOPSIS
    Convert vCard text to contact object
    
.DESCRIPTION
    Parses vCard text format and converts to standardized contact object.
    
.PARAMETER VCardText
    vCard text content
    
.EXAMPLE
    Convert-VCardToContact -VCardText $vCardContent
#>
function Convert-VCardToContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VCardText
    )
    
    $contact = [PSCustomObject]@{
        DisplayName     = ""
        GivenName       = ""
        Surname         = ""
        MiddleName      = ""
        CompanyName     = ""
        JobTitle        = ""
        Department      = ""
        EmailAddresses  = @()
        BusinessPhones  = @()
        HomePhones      = @()
        MobilePhone     = ""
        BusinessAddress = @{}
        HomeAddress     = @{}
        PersonalNotes   = ""
        Birthday        = $null
        Source          = "vCard Import"
    }
    
    # Parse vCard lines
    $lines = $VCardText -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    
    foreach ($line in $lines) {
        if ($line -match "^([^:]+):(.*)$") {
            $field = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            switch -Regex ($field) {
                "^FN$" {
                    $contact.DisplayName = $value
                }
                "^N$" {
                    # Format: Surname;GivenName;MiddleName;Prefix;Suffix
                    $nameParts = $value -split ";"
                    if ($nameParts.Length -gt 0) { $contact.Surname = $nameParts[0] }
                    if ($nameParts.Length -gt 1) { $contact.GivenName = $nameParts[1] }
                    if ($nameParts.Length -gt 2) { $contact.MiddleName = $nameParts[2] }
                }
                "^EMAIL" {
                    $contact.EmailAddresses += @{ Address = $value }
                }
                "^TEL.*WORK" {
                    $contact.BusinessPhones += $value
                }
                "^TEL.*HOME" {
                    $contact.HomePhones += $value
                }
                "^TEL.*CELL" {
                    $contact.MobilePhone = $value
                }
                "^ORG$" {
                    $contact.CompanyName = $value
                }
                "^TITLE$" {
                    $contact.JobTitle = $value
                }
                "^NOTE$" {
                    $contact.PersonalNotes = $value
                }
            }
        }
    }
    
    return $contact
}

<#
.SYNOPSIS
    Validate contacts array
    
.DESCRIPTION
    Validates an array of contacts and returns validation results.
    
.PARAMETER Contacts
    Array of contact objects to validate
    
.EXAMPLE
    Test-ContactsValidation -Contacts $contacts
#>
function Test-ContactsValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Contacts
    )
    
    $validContacts = @()
    $validationErrors = @()
    
    for ($i = 0; $i -lt $Contacts.Count; $i++) {
        $contact = $Contacts[$i]
        $errors = @()
        
        # Required field validation
        if ([string]::IsNullOrWhiteSpace($contact.DisplayName)) {
            $errors += "DisplayName is required"
        }
        
        # Email validation
        if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) {
            foreach ($email in $contact.EmailAddresses) {
                if ($email.Address -and $email.Address -notmatch "^[^@]+@[^@]+\.[^@]+$") {
                    $errors += "Invalid email format: $($email.Address)"
                }
            }
        }
        
        if ($errors.Count -eq 0) {
            $validContacts += $contact
        }
        else {
            $validationErrors += @{
                ContactIndex = $i
                Contact      = $contact.DisplayName
                ErrorMessage = $errors -join "; "
            }
        }
    }
    
    return @{
        ValidContacts    = $validContacts
        ValidCount       = $validContacts.Count
        InvalidCount     = $validationErrors.Count
        ValidationErrors = $validationErrors
    }
}

<#
.SYNOPSIS
    Get or create contact folder
    
.DESCRIPTION
    Gets an existing contact folder or creates a new one if it doesn't exist.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER FolderName
    Contact folder name
    
.EXAMPLE
    Get-OrCreateContactFolder -UserEmail "user@domain.com" -FolderName "Vendors"
#>
function Get-OrCreateContactFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    
    try {
        Write-Verbose "Getting or creating contact folder: $FolderName"
        
        # Get existing folders
        $folders = Get-UserContactFolders -UserEmail $UserEmail
        $existingFolder = $folders | Where-Object { $_.DisplayName -eq $FolderName }
        
        if ($existingFolder) {
            Write-Verbose "Found existing folder: $FolderName"
            return $existingFolder
        }
        
        # Create new folder
        Write-Information "Creating new contact folder: $FolderName" -InformationAction Continue
        
        if (Get-Module -ListAvailable -Name "Microsoft.Graph.PersonalContacts") {
            Import-Module Microsoft.Graph.PersonalContacts -Force -Verbose:$false
            
            $newFolder = New-MgUserContactFolder -UserId $UserEmail -DisplayName $FolderName
            return $newFolder
        }
        else {
            # Use REST API
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contactFolders"
            $body = @{ displayName = $FolderName } | ConvertTo-Json
            $newFolder = Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            return $newFolder
        }
    }
    catch {
        Write-Error "Failed to get or create contact folder: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Merge duplicate contacts
    
.DESCRIPTION
    Merges duplicate contacts by combining information from multiple sources.
    Provides interactive prompts for conflict resolution.
    
.PARAMETER ExistingContacts
    Array of existing contacts that match new contacts
    
.PARAMETER NewContacts
    Array of new contacts to merge with existing ones
    
.PARAMETER InteractiveMode
    Whether to prompt user for merge decisions (default: true)
    
.EXAMPLE
    Merge-DuplicateContacts -ExistingContacts $existing -NewContacts $new -InteractiveMode $true
#>
function Merge-DuplicateContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ExistingContacts,
        
        [Parameter(Mandatory = $true)]
        [array]$NewContacts,
        
        [Parameter(Mandatory = $false)]
        [bool]$InteractiveMode = $true
    )
    
    try {
        Write-Information "Starting duplicate contact merge process..." -InformationAction Continue
        $mergedResults = @{
            MergedContacts  = @()
            SkippedContacts = @()
            UpdatedContacts = @()
        }
        
        # Group contacts by email for merging
        $mergeGroups = @{}
        
        # Add existing contacts to merge groups
        foreach ($existingContact in $ExistingContacts) {
            if ($existingContact.EmailAddresses -and $existingContact.EmailAddresses.Count -gt 0) {
                $email = $existingContact.EmailAddresses[0].Address.ToLower()
                if (-not $mergeGroups.ContainsKey($email)) {
                    $mergeGroups[$email] = @{
                        Existing = @()
                        New      = @()
                    }
                }
                $mergeGroups[$email].Existing += $existingContact
            }
        }
        
        # Add new contacts to merge groups
        foreach ($newContact in $NewContacts) {
            if ($newContact.EmailAddresses -and $newContact.EmailAddresses.Count -gt 0) {
                $email = $newContact.EmailAddresses[0].Address.ToLower()
                if ($mergeGroups.ContainsKey($email)) {
                    $mergeGroups[$email].New += $newContact
                }
            }
        }
        
        # Process each merge group
        foreach ($email in $mergeGroups.Keys) {
            $group = $mergeGroups[$email]
            
            if ($group.Existing.Count -gt 0 -and $group.New.Count -gt 0) {
                Write-Information "" -InformationAction Continue
                Write-Information "========================================" -InformationAction Continue
                Write-Information "🔍 DUPLICATE CONTACT DETECTED" -InformationAction Continue
                Write-Information "========================================" -InformationAction Continue
                Write-Information "Email: $email" -InformationAction Continue
                Write-Information "" -InformationAction Continue
                
                $existing = $group.Existing[0]
                $new = $group.New[0]
                
                # Show detailed comparison
                Write-Information "📋 DETAILED COMPARISON:" -InformationAction Continue
                Write-Information "" -InformationAction Continue
                
                $comparisonFields = @(
                    @{ Name = "Name"; ExistingValue = $existing.DisplayName; NewValue = $new.DisplayName },
                    @{ Name = "Company"; ExistingValue = $existing.CompanyName; NewValue = $new.CompanyName },
                    @{ Name = "Job Title"; ExistingValue = $existing.JobTitle; NewValue = $new.JobTitle },
                    @{ Name = "Business Phone"; ExistingValue = ($existing.BusinessPhones -join ', '); NewValue = ($new.BusinessPhones -join ', ') },
                    @{ Name = "Mobile Phone"; ExistingValue = $existing.MobilePhone; NewValue = $new.MobilePhone },
                    @{ Name = "Home Phone"; ExistingValue = ($existing.HomePhones -join ', '); NewValue = ($new.HomePhones -join ', ') },
                    @{ Name = "Department"; ExistingValue = $existing.Department; NewValue = $new.Department },
                    @{ Name = "Business Address"; ExistingValue = "$($existing.BusinessAddress.Street), $($existing.BusinessAddress.City), $($existing.BusinessAddress.State)"; NewValue = "$($new.BusinessAddress.Street), $($new.BusinessAddress.City), $($new.BusinessAddress.State)" },
                    @{ Name = "Notes"; ExistingValue = $existing.PersonalNotes; NewValue = $new.PersonalNotes }
                )
                
                foreach ($field in $comparisonFields) {
                    $existingVal = if ([string]::IsNullOrWhiteSpace($field.ExistingValue)) { "[empty]" } else { $field.ExistingValue }
                    $newVal = if ([string]::IsNullOrWhiteSpace($field.NewValue)) { "[empty]" } else { $field.NewValue }
                    
                    Write-Information "  $($field.Name):" -InformationAction Continue
                    Write-Information "    📁 Existing ($($existing.SourceFolderName)): $existingVal" -InformationAction Continue
                    Write-Information "    📥 New (to import): $newVal" -InformationAction Continue
                    
                    if ($existingVal -ne $newVal) {
                        Write-Information "    ⚠️  VALUES DIFFER" -InformationAction Continue
                    }
                    Write-Information "" -InformationAction Continue
                }
                
                if ($InteractiveMode) {
                    Write-Information "========================================" -InformationAction Continue
                    Write-Information "🎯 MERGE OPTIONS:" -InformationAction Continue
                    Write-Information "1. Skip importing (keep existing contact only)" -InformationAction Continue
                    Write-Information "2. Import as separate contact (allow duplicate)" -InformationAction Continue
                    Write-Information "3. Merge contacts with selective field control" -InformationAction Continue
                    Write-Information "4. Replace existing contact entirely" -InformationAction Continue
                    Write-Information "========================================" -InformationAction Continue
                    
                    do {
                        $choice = Read-Host "Enter your choice (1-4)"
                    } while ($choice -notin @("1", "2", "3", "4"))
                    
                    switch ($choice) {
                        "1" {
                            Write-Information "✅ Skipping import for: $($new.DisplayName)" -InformationAction Continue
                            $mergedResults.SkippedContacts += $new
                        }
                        "2" {
                            Write-Information "✅ Importing as separate contact: $($new.DisplayName)" -InformationAction Continue
                            $mergedResults.MergedContacts += $new
                        }
                        "3" {
                            Write-Information "🔧 Starting interactive merge..." -InformationAction Continue
                            $mergedContact = Invoke-InteractiveMerge -ExistingContact $existing -NewContact $new
                            if ($mergedContact) {
                                $mergedResults.UpdatedContacts += $mergedContact
                                Write-Information "✅ Contact will be updated with merged data" -InformationAction Continue
                            }
                            else {
                                $mergedResults.SkippedContacts += $new
                                Write-Information "❌ Merge cancelled - skipping import" -InformationAction Continue
                            }
                        }
                        "4" {
                            Write-Information "⚠️ Replacing existing contact entirely..." -InformationAction Continue
                            Write-Warning "This will completely replace the existing contact. Are you sure? (y/N)"
                            $confirm = Read-Host
                            if ($confirm.ToLower() -eq 'y') {
                                $mergedResults.UpdatedContacts += $new
                                Write-Information "✅ Existing contact will be replaced" -InformationAction Continue
                            }
                            else {
                                $mergedResults.SkippedContacts += $new
                                Write-Information "❌ Replace cancelled - skipping import" -InformationAction Continue
                            }
                        }
                    }
                }
                else {
                    # Non-interactive mode - default to skip
                    Write-Information "🤖 Non-interactive mode: Skipping duplicate contact: $($new.DisplayName)" -InformationAction Continue
                    $mergedResults.SkippedContacts += $new
                }
            }
        }
        
        return $mergedResults
        
    }
    catch {
        Write-Error "Failed to merge duplicate contacts: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Interactive merge of two contacts with field-by-field control
    
.DESCRIPTION
    Provides detailed field-by-field control during contact merge process.
    
.PARAMETER ExistingContact
    Existing contact to merge into
    
.PARAMETER NewContact
    New contact data to merge from
    
.EXAMPLE
    Invoke-InteractiveMerge -ExistingContact $existing -NewContact $new
#>
function Invoke-InteractiveMerge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$ExistingContact,
        
        [Parameter(Mandatory = $true)]
        [PSObject]$NewContact
    )
    
    try {
        Write-Information "" -InformationAction Continue
        Write-Information "🔧 INTERACTIVE FIELD-BY-FIELD MERGE" -InformationAction Continue
        Write-Information "=====================================" -InformationAction Continue
        Write-Information "For each field, choose which value to keep:" -InformationAction Continue
        Write-Information "  E = Keep existing value" -InformationAction Continue
        Write-Information "  N = Use new value" -InformationAction Continue
        Write-Information "  C = Combine both values" -InformationAction Continue
        Write-Information "  S = Skip field (leave empty)" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        
        # Create merged contact starting with existing
        $mergedContact = $ExistingContact.PSObject.Copy()
        
        # Define fields to merge interactively
        $mergeableFields = @(
            @{ 
                Name          = "Display Name"
                Property      = "DisplayName"
                ExistingValue = $ExistingContact.DisplayName
                NewValue      = $NewContact.DisplayName
                AllowCombine  = $false
            },
            @{ 
                Name          = "Company Name"
                Property      = "CompanyName"
                ExistingValue = $ExistingContact.CompanyName
                NewValue      = $NewContact.CompanyName
                AllowCombine  = $false
            },
            @{ 
                Name          = "Job Title"
                Property      = "JobTitle"
                ExistingValue = $ExistingContact.JobTitle
                NewValue      = $NewContact.JobTitle
                AllowCombine  = $false
            },
            @{ 
                Name          = "Department"
                Property      = "Department"
                ExistingValue = $ExistingContact.Department
                NewValue      = $NewContact.Department
                AllowCombine  = $false
            },
            @{ 
                Name          = "Business Phone"
                Property      = "BusinessPhones"
                ExistingValue = ($ExistingContact.BusinessPhones -join ', ')
                NewValue      = ($NewContact.BusinessPhones -join ', ')
                AllowCombine  = $true
            },
            @{ 
                Name          = "Mobile Phone"
                Property      = "MobilePhone"
                ExistingValue = $ExistingContact.MobilePhone
                NewValue      = $NewContact.MobilePhone
                AllowCombine  = $false
            },
            @{ 
                Name          = "Home Phone"
                Property      = "HomePhones"
                ExistingValue = ($ExistingContact.HomePhones -join ', ')
                NewValue      = ($NewContact.HomePhones -join ', ')
                AllowCombine  = $true
            },
            @{ 
                Name          = "Personal Notes"
                Property      = "PersonalNotes"
                ExistingValue = $ExistingContact.PersonalNotes
                NewValue      = $NewContact.PersonalNotes
                AllowCombine  = $true
            }
        )
        
        $changesCount = 0
        
        foreach ($field in $mergeableFields) {
            $existingVal = if ([string]::IsNullOrWhiteSpace($field.ExistingValue)) { "[empty]" } else { $field.ExistingValue }
            $newVal = if ([string]::IsNullOrWhiteSpace($field.NewValue)) { "[empty]" } else { $field.NewValue }
            
            # Skip if values are the same (including both empty)
            if ($field.ExistingValue -eq $field.NewValue) {
                Write-Information "✅ $($field.Name): Values are identical - keeping existing" -InformationAction Continue
                continue
            }
            
            # Skip if both values are empty/null (no meaningful choice to make)
            if ([string]::IsNullOrWhiteSpace($field.ExistingValue) -and [string]::IsNullOrWhiteSpace($field.NewValue)) {
                Write-Information "✅ $($field.Name): Both values are empty - skipping" -InformationAction Continue
                continue
            }
            
            Write-Information "📝 $($field.Name):" -InformationAction Continue
            Write-Information "    [E] Existing: $existingVal" -InformationAction Continue
            Write-Information "    [N] New:      $newVal" -InformationAction Continue
            
            # Determine if combine option should be available
            $canCombine = $field.AllowCombine -and -not [string]::IsNullOrWhiteSpace($field.ExistingValue) -and -not [string]::IsNullOrWhiteSpace($field.NewValue)
            
            if ($canCombine) {
                Write-Information "    [C] Combined: $($field.ExistingValue); $($field.NewValue)" -InformationAction Continue
            }
            
            Write-Information "    [S] Skip (leave empty)" -InformationAction Continue
            
            do {
                if ($canCombine) {
                    $choice = Read-Host "    Choice (E/N/C/S)"
                    $validChoices = @("E", "N", "C", "S", "e", "n", "c", "s")
                }
                else {
                    $choice = Read-Host "    Choice (E/N/S)"
                    $validChoices = @("E", "N", "S", "e", "n", "s")
                }
            } while ($choice -notin $validChoices)
            
            $choice = $choice.ToUpper()
            $changesCount++
            
            switch ($choice) {
                "E" {
                    Write-Information "    ✅ Keeping existing value" -InformationAction Continue
                    # No change needed - already has existing value
                }
                "N" {
                    Write-Information "    ✅ Using new value" -InformationAction Continue
                    # Update the merged contact with new value
                    switch ($field.Property) {
                        "BusinessPhones" {
                            $mergedContact.BusinessPhones = $NewContact.BusinessPhones
                        }
                        "HomePhones" {
                            $mergedContact.HomePhones = $NewContact.HomePhones
                        }
                        default {
                            $mergedContact.($field.Property) = $NewContact.($field.Property)
                        }
                    }
                }
                "C" {
                    if ($field.AllowCombine) {
                        Write-Information "    ✅ Combining values" -InformationAction Continue
                        switch ($field.Property) {
                            "BusinessPhones" {
                                $combined = @()
                                if ($ExistingContact.BusinessPhones) { $combined += $ExistingContact.BusinessPhones }
                                if ($NewContact.BusinessPhones) { $combined += $NewContact.BusinessPhones }
                                $mergedContact.BusinessPhones = ($combined | Select-Object -Unique)
                            }
                            "HomePhones" {
                                $combined = @()
                                if ($ExistingContact.HomePhones) { $combined += $ExistingContact.HomePhones }
                                if ($NewContact.HomePhones) { $combined += $NewContact.HomePhones }
                                $mergedContact.HomePhones = ($combined | Select-Object -Unique)
                            }
                            "PersonalNotes" {
                                $combinedNotes = @()
                                if (-not [string]::IsNullOrWhiteSpace($ExistingContact.PersonalNotes)) { 
                                    $combinedNotes += $ExistingContact.PersonalNotes 
                                }
                                if (-not [string]::IsNullOrWhiteSpace($NewContact.PersonalNotes)) { 
                                    $combinedNotes += $NewContact.PersonalNotes 
                                }
                                $mergedContact.PersonalNotes = $combinedNotes -join "; "
                            }
                        }
                    }
                }
                "S" {
                    Write-Information "    ✅ Skipping field (leaving empty)" -InformationAction Continue
                    # Clear the field
                    switch ($field.Property) {
                        "BusinessPhones" {
                            $mergedContact.BusinessPhones = @()
                        }
                        "HomePhones" {
                            $mergedContact.HomePhones = @()
                        }
                        default {
                            $mergedContact.($field.Property) = ""
                        }
                    }
                }
            }
            Write-Information "" -InformationAction Continue
        }
        
        # Show final merge summary
        Write-Information "=====================================" -InformationAction Continue
        Write-Information "📋 MERGE SUMMARY" -InformationAction Continue
        Write-Information "=====================================" -InformationAction Continue
        Write-Information "Final merged contact:" -InformationAction Continue
        Write-Information "  Name: $($mergedContact.DisplayName)" -InformationAction Continue
        Write-Information "  Company: $($mergedContact.CompanyName)" -InformationAction Continue
        Write-Information "  Job Title: $($mergedContact.JobTitle)" -InformationAction Continue
        Write-Information "  Business Phone: $($mergedContact.BusinessPhones -join ', ')" -InformationAction Continue
        Write-Information "  Mobile Phone: $($mergedContact.MobilePhone)" -InformationAction Continue
        Write-Information "  Notes: $($mergedContact.PersonalNotes)" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        
        Write-Information "Apply this merge? (Y/n)" -InformationAction Continue
        $confirm = Read-Host
        
        if ($confirm.ToLower() -ne 'n') {
            Write-Information "✅ Merge approved!" -InformationAction Continue
            return $mergedContact
        }
        else {
            Write-Information "❌ Merge cancelled" -InformationAction Continue
            return $null
        }
        
    }
    catch {
        Write-Error "Failed to perform interactive merge: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Find duplicate contacts
    
.DESCRIPTION
    Identifies potential duplicate contacts based on email address matching.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER FolderId
    Contact folder ID to search
    
.PARAMETER NewContacts
    Array of new contacts to check for duplicates
    
.EXAMPLE
    Find-DuplicateContacts -UserEmail "user@domain.com" -FolderId "folder-id" -NewContacts $contacts
#>
function Find-DuplicateContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$FolderId,
        
        [Parameter(Mandatory = $true)]
        [array]$NewContacts,
        
        [Parameter(Mandatory = $false)]
        [switch]$GlobalSearch
    )
    
    try {
        if ($GlobalSearch) {
            Write-Verbose "Finding duplicate contacts across ALL FOLDERS for user: $UserEmail"
            
            $allContacts = @()
            $folderContactCount = @{}
            
            # FIRST: Get contacts from DEFAULT "Contacts" folder using direct API
            Write-Verbose "Retrieving contacts from default 'Contacts' folder"
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contacts"
            $defaultFolderContacts = @()
            
            do {
                $response = Invoke-MgGraphRequest -Uri $uri -Method GET
                if ($response.value) {
                    # Add folder information to each contact
                    foreach ($contact in $response.value) {
                        $contact | Add-Member -NotePropertyName "SourceFolderName" -NotePropertyValue "Contacts" -Force
                        $contact | Add-Member -NotePropertyName "SourceFolderId" -NotePropertyValue "default" -Force
                    }
                    $defaultFolderContacts += $response.value
                }
                $uri = $response.'@odata.nextLink'  # Get next page URL
            } while ($uri)
            
            $folderContactCount["Contacts"] = $defaultFolderContacts.Count
            $allContacts += $defaultFolderContacts
            Write-Verbose "Retrieved $($defaultFolderContacts.Count) contacts from default 'Contacts' folder"
            
            # SECOND: Get all named contact folders
            $contactFolders = Get-UserContactFolders -UserEmail $UserEmail
            Write-Verbose "Found $($contactFolders.Count) named contact folders to search"
            
            # Get contacts from each named folder
            foreach ($folder in $contactFolders) {
                Write-Verbose "Retrieving contacts from named folder: $($folder.DisplayName)"
                $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contactFolders/$($folder.Id)/contacts"
                $folderContacts = @()
                
                do {
                    $response = Invoke-MgGraphRequest -Uri $uri -Method GET
                    if ($response.value) {
                        # Add folder information to each contact
                        foreach ($contact in $response.value) {
                            $contact | Add-Member -NotePropertyName "SourceFolderName" -NotePropertyValue $folder.DisplayName -Force
                            $contact | Add-Member -NotePropertyName "SourceFolderId" -NotePropertyValue $folder.Id -Force
                        }
                        $folderContacts += $response.value
                    }
                    $uri = $response.'@odata.nextLink'  # Get next page URL
                } while ($uri)
                
                $folderContactCount[$folder.DisplayName] = $folderContacts.Count
                $allContacts += $folderContacts
                Write-Verbose "Retrieved $($folderContacts.Count) contacts from named folder: $($folder.DisplayName)"
            }
            
            Write-Verbose "Retrieved $($allContacts.Count) total contacts from default folder + $($contactFolders.Count) named folders"
            Write-Verbose "Folder breakdown: $(($folderContactCount.Keys | ForEach-Object { "$_ ($($folderContactCount[$_]))" }) -join ', ')"
            
            $existingContacts = @()
            if ($allContacts) {
                foreach ($graphContact in $allContacts) {
                    # Convert Graph API format to our internal format
                    $contact = [PSCustomObject]@{
                        Id               = $graphContact.id
                        DisplayName      = $graphContact.displayName
                        GivenName        = $graphContact.givenName
                        Surname          = $graphContact.surname
                        MiddleName       = $graphContact.middleName
                        CompanyName      = $graphContact.companyName
                        JobTitle         = $graphContact.jobTitle
                        Department       = $graphContact.department
                        EmailAddresses   = if ($graphContact.emailAddresses) { 
                            $graphContact.emailAddresses | Where-Object { $_.address } | ForEach-Object { @{ Address = $_.address } }
                        }
                        else { @() }
                        BusinessPhones   = if ($graphContact.businessPhones) { $graphContact.businessPhones } else { @() }
                        HomePhones       = if ($graphContact.homePhones) { $graphContact.homePhones } else { @() }
                        MobilePhone      = $graphContact.mobilePhone
                        PersonalNotes    = $graphContact.personalNotes
                        SourceFolderName = $graphContact.SourceFolderName
                        SourceFolderId   = $graphContact.SourceFolderId
                        ParentFolderId   = $graphContact.parentFolderId
                        BusinessAddress  = if ($graphContact.businessAddress) {
                            @{
                                Street     = $graphContact.businessAddress.street
                                City       = $graphContact.businessAddress.city
                                State      = $graphContact.businessAddress.state
                                PostalCode = $graphContact.businessAddress.postalCode
                                Country    = $graphContact.businessAddress.countryOrRegion
                            }
                        }
                        else { @{} }
                        HomeAddress      = if ($graphContact.homeAddress) {
                            @{
                                Street     = $graphContact.homeAddress.street
                                City       = $graphContact.homeAddress.city
                                State      = $graphContact.homeAddress.state
                                PostalCode = $graphContact.homeAddress.postalCode
                                Country    = $graphContact.homeAddress.countryOrRegion
                            }
                        }
                        else { @{} }
                    }
                    $existingContacts += $contact
                }
            }
            
            Write-Verbose "Found $($existingContacts.Count) existing contacts using ALL FOLDERS method"
        }
        else {
            Write-Verbose "Finding duplicate contacts in folder: $FolderId"
            
            # Get existing contacts from specific folder only
            $existingContacts = Get-ContactsFromFolder -UserEmail $UserEmail -FolderId $FolderId
        }
        
        if (-not $existingContacts -or $existingContacts.Count -eq 0) {
            return @{
                DuplicateCount    = 0
                UniqueContacts    = $NewContacts
                DuplicateContacts = @()
                ExistingContacts  = @()
            }
        }
        
        # Build email lookup for existing contacts
        $existingEmails = @{}
        foreach ($contact in $existingContacts) {
            if ($contact -and $contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) {
                $emailAddress = $contact.EmailAddresses[0].Address
                if ($emailAddress) {
                    $email = $emailAddress.ToLower()
                    if (-not $existingEmails.ContainsKey($email)) {
                        $existingEmails[$email] = @()
                    }
                    $existingEmails[$email] += $contact
                }
            }
        }
        
        # Identify duplicates
        $uniqueContacts = @()
        $duplicateContacts = @()
        $matchingExistingContacts = @()
        
        foreach ($newContact in $NewContacts) {
            $isDuplicate = $false
            
            if ($newContact -and $newContact.EmailAddresses -and $newContact.EmailAddresses.Count -gt 0) {
                $emailAddress = $newContact.EmailAddresses[0].Address
                if ($emailAddress) {
                    $email = $emailAddress.ToLower()
                    
                    if ($existingEmails.ContainsKey($email)) {
                        $duplicateContacts += $newContact
                        # Add all matching existing contacts (could be multiple across folders)
                        $matchingExistingContacts += $existingEmails[$email]
                        $isDuplicate = $true
                        
                        if ($GlobalSearch -and $existingEmails[$email].Count -gt 0) {
                            $folderInfo = $existingEmails[$email] | Select-Object -First 1
                            Write-Verbose "Found duplicate for '$($newContact.DisplayName)' in folder: $($folderInfo.SourceFolderName)"
                        }
                    }
                }
            }
            
            if (-not $isDuplicate) {
                $uniqueContacts += $newContact
            }
        }
        
        return @{
            DuplicateCount      = $duplicateContacts.Count
            UniqueContacts      = $uniqueContacts
            DuplicateContacts   = $duplicateContacts
            ExistingContacts    = $matchingExistingContacts
            AllExistingContacts = $existingContacts  # Add this for debugging
        }
    }
    catch {
        Write-Error "Failed to find duplicate contacts: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Convert contact to Microsoft Graph format
    
.DESCRIPTION
    Converts a contact object to Microsoft Graph API format.
    
.PARAMETER Contact
    Contact object to convert
    
.EXAMPLE
    Convert-ToGraphContact -Contact $contact
#>
function Convert-ToGraphContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Contact
    )
    
    $graphContact = @{
        displayName   = $Contact.DisplayName
        givenName     = $Contact.GivenName
        surname       = $Contact.Surname
        middleName    = $Contact.MiddleName
        companyName   = $Contact.CompanyName
        jobTitle      = $Contact.JobTitle
        department    = $Contact.Department
        personalNotes = $Contact.PersonalNotes
    }
    
    # Handle email addresses
    if ($Contact.EmailAddresses -and $Contact.EmailAddresses.Count -gt 0) {
        $graphContact.emailAddresses = @()
        foreach ($email in $Contact.EmailAddresses) {
            $graphContact.emailAddresses += @{
                address = $email.Address
                name    = $Contact.DisplayName
            }
        }
    }
    
    # Handle phone numbers
    if ($Contact.BusinessPhones -and $Contact.BusinessPhones.Count -gt 0) {
        $graphContact.businessPhones = $Contact.BusinessPhones
    }
    
    if ($Contact.HomePhones -and $Contact.HomePhones.Count -gt 0) {
        $graphContact.homePhones = $Contact.HomePhones
    }
    
    if ($Contact.MobilePhone) {
        $graphContact.mobilePhone = $Contact.MobilePhone
    }
    
    # Handle addresses
    if ($Contact.BusinessAddress -and $Contact.BusinessAddress.Keys.Count -gt 0) {
        $graphContact.businessAddress = @{
            street          = $Contact.BusinessAddress.Street
            city            = $Contact.BusinessAddress.City
            state           = $Contact.BusinessAddress.State
            postalCode      = $Contact.BusinessAddress.PostalCode
            countryOrRegion = $Contact.BusinessAddress.Country
        }
    }
    
    if ($Contact.HomeAddress -and $Contact.HomeAddress.Keys.Count -gt 0) {
        $graphContact.homeAddress = @{
            street          = $Contact.HomeAddress.Street
            city            = $Contact.HomeAddress.City
            state           = $Contact.HomeAddress.State
            postalCode      = $Contact.HomeAddress.PostalCode
            countryOrRegion = $Contact.HomeAddress.Country
        }
    }
    
    return $graphContact
}

<#
.SYNOPSIS
    Add contact to folder
    
.DESCRIPTION
    Adds a contact to the specified folder using Microsoft Graph API.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER FolderId
    Contact folder ID
    
.PARAMETER Contact
    Contact object in Graph format
    
.EXAMPLE
    Add-ContactToFolder -UserEmail "user@domain.com" -FolderId "folder-id" -Contact $graphContact
#>
function Add-ContactToFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$FolderId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Contact
    )
    
    try {
        Write-Verbose "Adding contact to folder: $($Contact.displayName)"
        
        if (Get-Module -ListAvailable -Name "Microsoft.Graph.PersonalContacts") {
            Import-Module Microsoft.Graph.PersonalContacts -Force -Verbose:$false
            
            # Convert hashtable to parameters for New-MgUserContactFolderContact
            $contactParams = @{
                UserId          = $UserEmail
                ContactFolderId = $FolderId
            }
            
            # Add contact properties
            foreach ($key in $Contact.Keys) {
                $contactParams[$key] = $Contact[$key]
            }
            
            $createdContact = New-MgUserContactFolderContact @contactParams
            return $createdContact
        }
        else {
            # Use REST API
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contactFolders/$FolderId/contacts"
            $body = $Contact | ConvertTo-Json -Depth 10
            $createdContact = Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
            return $createdContact
        }
    }
    catch {
        Write-Error "Failed to add contact to folder: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Import CSV with intelligent folder placement and duplicate handling
    
.DESCRIPTION
    Imports contacts from CSV with smart folder placement based on company names,
    comprehensive duplicate detection across all folders, and intelligent merging.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER ImportFilePath
    Path to CSV file to import
    
.PARAMETER CompanyFolderMapping
    Hashtable mapping company names to folder names (e.g., @{"Acme Corp" = "Vendors"; "Internal" = "Employees"})
    
.PARAMETER DefaultFolder
    Default folder for contacts without specific company mapping (default: "Contacts")
    
.PARAMETER DuplicateAction
    How to handle duplicates: Skip, Merge, Overwrite (default: Merge)
    
.PARAMETER InteractiveMode
    Whether to prompt for merge decisions (default: true)
    
.PARAMETER CreateFolders
    Whether to create folders if they don't exist (default: true)
    
.EXAMPLE
    Import-CSVWithIntelligentPlacement -UserEmail "user@domain.com" -ImportFilePath ".\contacts.csv" -CompanyFolderMapping @{"Acme Corp" = "Vendors"; "TechCorp" = "Partners"}
    
.EXAMPLE
    Import-CSVWithIntelligentPlacement -UserEmail "user@domain.com" -ImportFilePath ".\employees.csv" -DefaultFolder "Staff" -DuplicateAction "Merge" -InteractiveMode $false
#>
function Import-CSVWithIntelligentPlacement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$ImportFilePath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CompanyFolderMapping = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$DefaultFolder = "Contacts",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Skip", "Merge", "Overwrite")]
        [string]$DuplicateAction = "Merge",
        
        [Parameter(Mandatory = $false)]
        [bool]$InteractiveMode = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$CreateFolders = $true
    )
    
    try {
        Write-Information "🚀 Starting intelligent CSV import for user: $UserEmail" -InformationAction Continue
        Write-Information "📁 Import file: $ImportFilePath" -InformationAction Continue
        Write-Information "🎯 Duplicate action: $DuplicateAction" -InformationAction Continue
        Write-Information "🤖 Interactive mode: $InteractiveMode" -InformationAction Continue
        
        # Validate file exists
        if (-not (Test-Path $ImportFilePath)) {
            throw "Import file not found: $ImportFilePath"
        }
        
        # Validate authentication and permissions
        if (-not (Test-GraphConnection)) {
            throw "Microsoft Graph authentication required. Please run Initialize-GraphAuthenticationAuto or Initialize-GraphAuthentication first."
        }
        
        if (-not (Test-RequiredPermissions -RequiredScopes @("Contacts.ReadWrite", "User.Read"))) {
            throw "Required permissions not available. Please ensure Contacts.ReadWrite and User.Read permissions are granted."
        }
        
        # Import and validate CSV contacts
        Write-Information "📊 Parsing CSV file..." -InformationAction Continue
        $importedContacts = Import-ContactsFromCSV -FilePath $ImportFilePath -MappingProfile "Default"
        
        if (-not $importedContacts -or $importedContacts.Count -eq 0) {
            throw "No valid contacts found in CSV file"
        }
        
        Write-Information "✅ Found $($importedContacts.Count) contacts in CSV file" -InformationAction Continue
        
        # Validate contacts
        $validationResult = Test-ContactsValidation -Contacts $importedContacts
        Write-Information "🔍 Validation: $($validationResult.ValidCount) valid, $($validationResult.InvalidCount) invalid" -InformationAction Continue
        
        if ($validationResult.InvalidCount -gt 0) {
            Write-Warning "Found $($validationResult.InvalidCount) invalid contacts:"
            foreach ($error in $validationResult.ValidationErrors) {
                Write-Warning "  - Contact $($error.ContactIndex + 1): $($error.ErrorMessage)"
            }
        }
        
        if ($validationResult.ValidCount -eq 0) {
            throw "No valid contacts to import after validation"
        }
        
        # Group contacts by target folder based on company mapping
        Write-Information "🎯 Analyzing folder placement..." -InformationAction Continue
        $folderGroups = @{}
        $placementStats = @{}
        
        foreach ($contact in $validationResult.ValidContacts) {
            $targetFolder = $DefaultFolder  # Default fallback
            
            # Check if contact has company information
            if (-not [string]::IsNullOrWhiteSpace($contact.CompanyName)) {
                # Look for exact company match first
                $exactMatch = $CompanyFolderMapping.Keys | Where-Object { $contact.CompanyName -eq $_ }
                if ($exactMatch) {
                    $targetFolder = $CompanyFolderMapping[$exactMatch]
                    Write-Verbose "Exact company match: '$($contact.CompanyName)' → '$targetFolder'"
                }
                else {
                    # Look for partial company match (case-insensitive)
                    $partialMatch = $CompanyFolderMapping.Keys | Where-Object { 
                        $contact.CompanyName -like "*$_*" -or $_ -like "*$($contact.CompanyName)*" 
                    } | Select-Object -First 1
                    
                    if ($partialMatch) {
                        $targetFolder = $CompanyFolderMapping[$partialMatch]
                        Write-Verbose "Partial company match: '$($contact.CompanyName)' → '$targetFolder' (matched '$partialMatch')"
                    }
                    else {
                        Write-Verbose "No company match for '$($contact.CompanyName)', using default folder: '$targetFolder'"
                    }
                }
            }
            else {
                Write-Verbose "No company information for '$($contact.DisplayName)', using default folder: '$targetFolder'"
            }
            
            # Add to folder group
            if (-not $folderGroups.ContainsKey($targetFolder)) {
                $folderGroups[$targetFolder] = @()
                $placementStats[$targetFolder] = 0
            }
            $folderGroups[$targetFolder] += $contact
            $placementStats[$targetFolder]++
        }
        
        Write-Information "" -InformationAction Continue
        Write-Information "📋 FOLDER PLACEMENT ANALYSIS:" -InformationAction Continue
        foreach ($folder in $placementStats.Keys | Sort-Object) {
            Write-Information "  📁 ${folder}: $($placementStats[$folder]) contacts" -InformationAction Continue
        }
        Write-Information "" -InformationAction Continue
        
        # Get or create target folders
        Write-Information "📁 Preparing target folders..." -InformationAction Continue
        $targetFolders = @{}
        
        foreach ($folderName in $folderGroups.Keys) {
            try {
                if ($CreateFolders) {
                    $folder = Get-OrCreateContactFolder -UserEmail $UserEmail -FolderName $folderName
                    $targetFolders[$folderName] = $folder
                    Write-Verbose "✅ Folder ready: $folderName (ID: $($folder.Id))"
                }
                else {
                    # Only use existing folders
                    $existingFolders = Get-UserContactFolders -UserEmail $UserEmail
                    $folder = $existingFolders | Where-Object { $_.DisplayName -eq $folderName }
                    if (-not $folder -and $folderName -eq "Contacts") {
                        # Special case: "Contacts" is the default folder, create a placeholder
                        $targetFolders[$folderName] = @{ Id = "default"; DisplayName = "Contacts" }
                    }
                    elseif ($folder) {
                        $targetFolders[$folderName] = $folder
                        Write-Verbose "✅ Using existing folder: $folderName (ID: $($folder.Id))"
                    }
                    else {
                        Write-Warning "⚠️  Folder '$folderName' doesn't exist and CreateFolders is disabled. Contacts will go to default folder."
                        $targetFolders[$folderName] = @{ Id = "default"; DisplayName = "Contacts" }
                    }
                }
            }
            catch {
                Write-Warning "Failed to prepare folder '$folderName': $($_.Exception.Message). Using default folder."
                $targetFolders[$folderName] = @{ Id = "default"; DisplayName = "Contacts" }
            }
        }
        
        # Perform comprehensive duplicate detection across ALL folders
        Write-Information "🔍 Checking for duplicates across all folders..." -InformationAction Continue
        
        # Use our enhanced global search to find duplicates across all folders
        $duplicateResult = Find-DuplicateContacts -UserEmail $UserEmail -FolderId "dummy" -NewContacts $validationResult.ValidContacts -GlobalSearch
        
        Write-Information "" -InformationAction Continue
        Write-Information "📊 DUPLICATE DETECTION RESULTS:" -InformationAction Continue
        Write-Information "  ✅ Unique contacts: $($duplicateResult.UniqueContacts.Count)" -InformationAction Continue
        Write-Information "  ⚠️  Duplicate contacts: $($duplicateResult.DuplicateCount)" -InformationAction Continue
        Write-Information "  🗂️  Existing contacts checked: $($duplicateResult.AllExistingContacts.Count)" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        
        # Handle duplicates based on action
        $contactsToImport = @()
        $skippedDuplicates = @()
        $mergedContacts = @()
        
        if ($duplicateResult.DuplicateCount -gt 0) {
            switch ($DuplicateAction) {
                "Skip" {
                    Write-Information "⏭️  Skipping $($duplicateResult.DuplicateCount) duplicate contacts..." -InformationAction Continue
                    $contactsToImport = $duplicateResult.UniqueContacts
                    $skippedDuplicates = $duplicateResult.DuplicateContacts
                }
                "Overwrite" {
                    Write-Information "🔄 Will overwrite $($duplicateResult.DuplicateCount) existing contacts..." -InformationAction Continue
                    $contactsToImport = $validationResult.ValidContacts  # Import all, including duplicates
                }
                "Merge" {
                    Write-Information "🤝 Processing $($duplicateResult.DuplicateCount) duplicates for merging..." -InformationAction Continue
                    
                    # Add unique contacts first
                    $contactsToImport = $duplicateResult.UniqueContacts
                    
                    # Process duplicates for merging
                    if ($InteractiveMode) {
                        $mergeResult = Merge-DuplicateContacts -ExistingContacts $duplicateResult.ExistingContacts -NewContacts $duplicateResult.DuplicateContacts -InteractiveMode $true
                        $contactsToImport += $mergeResult.MergedContacts
                        $skippedDuplicates += $mergeResult.SkippedContacts
                        $mergedContacts += $mergeResult.UpdatedContacts
                    }
                    else {
                        # Non-interactive merge: use simple field combination logic
                        Write-Information "🤖 Performing automatic merge for duplicates..." -InformationAction Continue
                        foreach ($newContact in $duplicateResult.DuplicateContacts) {
                            # Find matching existing contact
                            $email = $newContact.EmailAddresses[0].Address.ToLower()
                            $existingContact = $duplicateResult.ExistingContacts | Where-Object { 
                                $_.EmailAddresses -and $_.EmailAddresses[0].Address.ToLower() -eq $email 
                            } | Select-Object -First 1
                            
                            if ($existingContact) {
                                # Auto-merge: combine non-empty fields, prefer new data
                                $mergedContact = $existingContact.PSObject.Copy()
                                
                                # Update with new data where new contact has more information
                                if (-not [string]::IsNullOrWhiteSpace($newContact.CompanyName) -and [string]::IsNullOrWhiteSpace($mergedContact.CompanyName)) {
                                    $mergedContact.CompanyName = $newContact.CompanyName
                                }
                                if (-not [string]::IsNullOrWhiteSpace($newContact.JobTitle) -and [string]::IsNullOrWhiteSpace($mergedContact.JobTitle)) {
                                    $mergedContact.JobTitle = $newContact.JobTitle
                                }
                                if ($newContact.BusinessPhones -and $newContact.BusinessPhones.Count -gt 0 -and $mergedContact.BusinessPhones.Count -eq 0) {
                                    $mergedContact.BusinessPhones = $newContact.BusinessPhones
                                }
                                if (-not [string]::IsNullOrWhiteSpace($newContact.MobilePhone) -and [string]::IsNullOrWhiteSpace($mergedContact.MobilePhone)) {
                                    $mergedContact.MobilePhone = $newContact.MobilePhone
                                }
                                
                                # Add merged contact for updating existing record
                                $mergedContacts += @{
                                    ExistingContactId = $existingContact.Id
                                    MergedContact     = $mergedContact
                                    TargetFolder      = $existingContact.SourceFolderName
                                }
                                
                                Write-Verbose "Auto-merged contact: $($newContact.DisplayName) with existing contact in $($existingContact.SourceFolderName)"
                            }
                        }
                    }
                }
            }
        }
        else {
            $contactsToImport = $validationResult.ValidContacts
        }
        
        # Import contacts to their respective folders
        Write-Information "" -InformationAction Continue
        Write-Information "📥 IMPORTING CONTACTS..." -InformationAction Continue
        
        $importResults = @{
            SuccessCount     = 0
            FailureCount     = 0
            UpdatedCount     = 0
            SkippedCount     = $skippedDuplicates.Count
            ImportedContacts = @()
            UpdatedContacts  = @()
            Errors           = @()
            FolderBreakdown  = @{}
        }
        
        # Import unique/new contacts
        foreach ($folderName in $folderGroups.Keys) {
            $folderContacts = $folderGroups[$folderName] | Where-Object { $_ -in $contactsToImport }
            if (-not $folderContacts -or $folderContacts.Count -eq 0) { continue }
            
            $targetFolder = $targetFolders[$folderName]
            Write-Information "  📁 Importing $($folderContacts.Count) contacts to '$folderName'..." -InformationAction Continue
            
            $importResults.FolderBreakdown[$folderName] = @{ Success = 0; Failed = 0 }
            
            foreach ($contact in $folderContacts) {
                try {
                    $graphContact = Convert-ToGraphContact -Contact $contact
                    
                    if ($targetFolder.Id -eq "default") {
                        # Import to default contacts folder
                        $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contacts"
                        $body = $graphContact | ConvertTo-Json -Depth 10
                        $createdContact = Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body
                    }
                    else {
                        # Import to specific folder
                        $createdContact = Add-ContactToFolder -UserEmail $UserEmail -FolderId $targetFolder.Id -Contact $graphContact
                    }
                    
                    $importResults.SuccessCount++
                    $importResults.FolderBreakdown[$folderName].Success++
                    $importResults.ImportedContacts += @{
                        Contact      = $contact
                        CreatedId    = $createdContact.id
                        TargetFolder = $folderName
                    }
                    
                    Write-Verbose "✅ Imported: $($contact.DisplayName) to $folderName"
                }
                catch {
                    $importResults.FailureCount++
                    $importResults.FolderBreakdown[$folderName].Failed++
                    $importResults.Errors += "Failed to import '$($contact.DisplayName)' to '$folderName': $($_.Exception.Message)"
                    Write-Warning "❌ Failed to import '$($contact.DisplayName)': $($_.Exception.Message)"
                }
            }
        }
        
        # Update merged contacts
        foreach ($mergeInfo in $mergedContacts) {
            try {
                Update-ExistingContact -UserEmail $UserEmail -ExistingContactId $mergeInfo.ExistingContactId -BackupContact $mergeInfo.MergedContact
                $importResults.UpdatedCount++
                $importResults.UpdatedContacts += $mergeInfo
                Write-Verbose "✅ Updated existing contact: $($mergeInfo.MergedContact.DisplayName)"
            }
            catch {
                $importResults.Errors += "Failed to update existing contact '$($mergeInfo.MergedContact.DisplayName)': $($_.Exception.Message)"
                Write-Warning "❌ Failed to update existing contact: $($_.Exception.Message)"
            }
        }
        
        # Final summary
        Write-Information "" -InformationAction Continue
        Write-Information "🎉 IMPORT COMPLETED!" -InformationAction Continue
        Write-Information "========================================" -InformationAction Continue
        Write-Information "📊 SUMMARY:" -InformationAction Continue
        Write-Information "  ✅ Successfully imported: $($importResults.SuccessCount) contacts" -InformationAction Continue
        Write-Information "  🔄 Updated existing: $($importResults.UpdatedCount) contacts" -InformationAction Continue
        Write-Information "  ⏭️  Skipped duplicates: $($importResults.SkippedCount) contacts" -InformationAction Continue
        Write-Information "  ❌ Failed imports: $($importResults.FailureCount) contacts" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        Write-Information "📁 FOLDER BREAKDOWN:" -InformationAction Continue
        foreach ($folder in $importResults.FolderBreakdown.Keys | Sort-Object) {
            $stats = $importResults.FolderBreakdown[$folder]
            Write-Information "  📂 ${folder}: $($stats.Success) imported, $($stats.Failed) failed" -InformationAction Continue
        }
        Write-Information "========================================" -InformationAction Continue
        
        if ($importResults.Errors.Count -gt 0) {
            Write-Information "" -InformationAction Continue
            Write-Information "⚠️  ERRORS ENCOUNTERED:" -InformationAction Continue
            foreach ($error in $importResults.Errors) {
                Write-Warning "  • $error"
            }
        }
        
        return @{
            Success          = $true
            Message          = "Intelligent CSV import completed successfully"
            TotalProcessed   = $validationResult.ValidCount
            SuccessCount     = $importResults.SuccessCount
            UpdatedCount     = $importResults.UpdatedCount
            SkippedCount     = $importResults.SkippedCount
            FailureCount     = $importResults.FailureCount
            FolderBreakdown  = $importResults.FolderBreakdown
            ImportedContacts = $importResults.ImportedContacts
            UpdatedContacts  = $importResults.UpdatedContacts
            Errors           = $importResults.Errors
        }
        
    }
    catch {
        $errorMessage = "Intelligent CSV import failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        return @{
            Success        = $false
            Message        = $errorMessage
            TotalProcessed = 0
            SuccessCount   = 0
            UpdatedCount   = 0
            SkippedCount   = 0
            FailureCount   = 0
        }
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Backup-UserContacts',
    'Restore-UserContacts',
    'Import-UserContacts',
    'Import-CSVWithIntelligentPlacement',
    'Get-UserContactFolders', 
    'Get-ContactsFromFolder',
    'Export-ContactsToVCard',
    'Export-ContactsToCSV',
    'Import-ContactsFromCSV',
    'Import-ContactsFromVCard',
    'Get-CSVFieldMapping',
    'Convert-CSVRowToContact',
    'Convert-VCardToContact',
    'Test-ContactsValidation',
    'Get-OrCreateContactFolder',
    'Find-DuplicateContacts',
    'Convert-ToGraphContact',
    'Add-ContactToFolder',
    'Update-ExistingContact'
)
