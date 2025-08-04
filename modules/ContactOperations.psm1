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
                    $conflictResult = Find-DuplicateContacts -UserEmail $UserEmail -FolderId $targetFolder.Id -NewContacts $contactsToRestore
                    
                    if ($conflictResult.DuplicateCount -gt 0) {
                        Write-Information "Found $($conflictResult.DuplicateCount) potential conflicts" -InformationAction Continue
                        
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
            foreach ($error in $validationResult.ValidationErrors) {
                Write-Warning "  - $($error.ContactIndex): $($error.Error)"
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
            $duplicateResult = Find-DuplicateContacts -UserEmail $UserEmail -FolderId $targetFolder.Id -NewContacts $contactsToImport
            
            if ($duplicateResult.DuplicateCount -gt 0) {
                Write-Information "Found $($duplicateResult.DuplicateCount) potential duplicates" -InformationAction Continue
                
                $contactsToImport = switch ($DuplicateAction) {
                    "Skip" {
                        Write-Information "Skipping $($duplicateResult.DuplicateCount) duplicate contacts" -InformationAction Continue
                        $duplicateResult.UniqueContacts
                    }
                    "Merge" {
                        Write-Information "Merging $($duplicateResult.DuplicateCount) duplicate contacts" -InformationAction Continue
                        Merge-DuplicateContacts -ExistingContacts $duplicateResult.ExistingContacts -NewContacts $duplicateResult.DuplicateContacts
                        $duplicateResult.UniqueContacts + $duplicateResult.MergedContacts
                    }
                }
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
                Error        = $errors -join "; "
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
        [array]$NewContacts
    )
    
    try {
        Write-Verbose "Finding duplicate contacts in folder: $FolderId"
        
        # Get existing contacts
        $existingContacts = Get-ContactsFromFolder -UserEmail $UserEmail -FolderId $FolderId
        
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
            if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) {
                $email = $contact.EmailAddresses[0].Address.ToLower()
                $existingEmails[$email] = $contact
            }
        }
        
        # Identify duplicates
        $uniqueContacts = @()
        $duplicateContacts = @()
        $matchingExistingContacts = @()
        
        foreach ($newContact in $NewContacts) {
            $isDuplicate = $false
            
            if ($newContact.EmailAddresses -and $newContact.EmailAddresses.Count -gt 0) {
                $email = $newContact.EmailAddresses[0].Address.ToLower()
                
                if ($existingEmails.ContainsKey($email)) {
                    $duplicateContacts += $newContact
                    $matchingExistingContacts += $existingEmails[$email]
                    $isDuplicate = $true
                }
            }
            
            if (-not $isDuplicate) {
                $uniqueContacts += $newContact
            }
        }
        
        return @{
            DuplicateCount    = $duplicateContacts.Count
            UniqueContacts    = $uniqueContacts
            DuplicateContacts = $duplicateContacts
            ExistingContacts  = $matchingExistingContacts
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

# Export module functions
Export-ModuleMember -Function @(
    'Backup-UserContacts',
    'Restore-UserContacts',
    'Import-UserContacts',
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
