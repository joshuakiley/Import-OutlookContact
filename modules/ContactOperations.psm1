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
            UserEmail = $UserEmail
            BackupDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            BackupFormat = $BackupFormat
            IncludePhotos = $IncludePhotos
            ContactFolder = $ContactFolder
            Version = "1.0.0"
            TotalContacts = 0
            ContactFolders = @()
            BackupFiles = @()
        }
        
        # Get user's contact folders
        Write-Information "Retrieving contact folders..." -InformationAction Continue
        $contactFolders = Get-UserContactFolders -UserEmail $UserEmail
        
        if ($contactFolders.Count -eq 0) {
            Write-Warning "No contact folders found for user: $UserEmail"
            return @{
                Success = $false
                Message = "No contact folders found"
                BackupPath = $userBackupPath
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
                        FileName = $backupFileName
                        FolderName = $folder.DisplayName
                        ContactCount = $contacts.Count
                        FileSize = (Get-Item $backupFilePath).Length
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
            Success = $true
            Message = "Backup completed successfully"
            BackupPath = $userBackupPath
            ContactCount = $totalContactsBackedUp
            FolderCount = $contactFolders.Count
            BackupFiles = $backupMetadata.BackupFiles
        }
        
    }
    catch {
        $errorMessage = "Backup operation failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        return @{
            Success = $false
            Message = $errorMessage
            BackupPath = $userBackupPath
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
                DisplayName = $contact.DisplayName
                GivenName = $contact.GivenName
                Surname = $contact.Surname
                MiddleName = $contact.MiddleName
                CompanyName = $contact.CompanyName
                JobTitle = $contact.JobTitle
                Department = $contact.Department
                EmailAddress = if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) { $contact.EmailAddresses[0].Address } else { "" }
                BusinessPhone = if ($contact.BusinessPhones -and $contact.BusinessPhones.Count -gt 0) { $contact.BusinessPhones[0] } else { "" }
                HomePhone = if ($contact.HomePhones -and $contact.HomePhones.Count -gt 0) { $contact.HomePhones[0] } else { "" }
                MobilePhone = $contact.MobilePhone
                BusinessStreet = if ($contact.BusinessAddress) { $contact.BusinessAddress.Street } else { "" }
                BusinessCity = if ($contact.BusinessAddress) { $contact.BusinessAddress.City } else { "" }
                BusinessState = if ($contact.BusinessAddress) { $contact.BusinessAddress.State } else { "" }
                BusinessPostalCode = if ($contact.BusinessAddress) { $contact.BusinessAddress.PostalCode } else { "" }
                BusinessCountry = if ($contact.BusinessAddress) { $contact.BusinessAddress.CountryOrRegion } else { "" }
                HomeStreet = if ($contact.HomeAddress) { $contact.HomeAddress.Street } else { "" }
                HomeCity = if ($contact.HomeAddress) { $contact.HomeAddress.City } else { "" }
                HomeState = if ($contact.HomeAddress) { $contact.HomeAddress.State } else { "" }
                HomePostalCode = if ($contact.HomeAddress) { $contact.HomeAddress.PostalCode } else { "" }
                HomeCountry = if ($contact.HomeAddress) { $contact.HomeAddress.CountryOrRegion } else { "" }
                PersonalNotes = $contact.PersonalNotes
                Birthday = $contact.Birthday
                CreatedDateTime = $contact.CreatedDateTime
                LastModifiedDateTime = $contact.LastModifiedDateTime
                Id = $contact.Id
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

# Export module functions
Export-ModuleMember -Function @(
    'Backup-UserContacts',
    'Get-UserContactFolders', 
    'Get-ContactsFromFolder',
    'Export-ContactsToVCard',
    'Export-ContactsToCSV'
)
