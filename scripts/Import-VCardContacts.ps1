#!/usr/bin/env pwsh

# Enhanced vCard Import Script with Advanced Features
Import-Module './modules/Authentication.psm1' -Force
Import-Module './modules/Configuration.psm1' -Force 
Import-Module './modules/ContactOperations.psm1' -Force

<#
.SYNOPSIS
    Enhanced vCard import with advanced parsing and field support
    
.DESCRIPTION
    Imports vCard files with enhanced parsing capabilities, supporting more vCard fields,
    multiple email addresses, phone numbers, addresses, and custom field mapping.
    
.PARAMETER FilePath
    Path to vCard file to import
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER ContactFolder
    Target contact folder name (default: "Contacts")
    
.PARAMETER DuplicateAction
    How to handle duplicates: Skip, Merge, Overwrite, Consolidate (default: "Merge")
    
.PARAMETER EnhancedParsing
    Use enhanced vCard parsing for better field extraction (default: true)
    
.PARAMETER ValidateOnly
    Only validate file without importing (default: false)
    
.EXAMPLE
    Import-VCardContacts -FilePath ".\contacts.vcf" -UserEmail "user@domain.com" -ContactFolder "Vendors" -DuplicateAction "Merge"
    
.EXAMPLE
    Import-VCardContacts -FilePath ".\iphone-export.vcf" -UserEmail "user@domain.com" -EnhancedParsing $true -ValidateOnly $true
#>
function Import-VCardContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $false)]
        [string]$ContactFolder = "Contacts",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Skip", "Merge", "Overwrite", "Consolidate")]
        [string]$DuplicateAction = "Merge",
        
        [Parameter(Mandatory = $false)]
        [bool]$EnhancedParsing = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$ValidateOnly = $false
    )
    
    try {
        Write-Host "🃏 ENHANCED VCARD IMPORT" -ForegroundColor Yellow
        Write-Host "=========================" -ForegroundColor Yellow
        Write-Information "User: $UserEmail" -InformationAction Continue
        Write-Information "File: $FilePath" -InformationAction Continue
        Write-Information "Target Folder: $ContactFolder" -InformationAction Continue
        Write-Information "Duplicate Action: $DuplicateAction" -InformationAction Continue
        Write-Information "Enhanced Parsing: $EnhancedParsing" -InformationAction Continue
        
        # Validate file exists
        if (-not (Test-Path $FilePath)) {
            throw "vCard file not found: $FilePath"
        }
        
        # Get file info
        $fileInfo = Get-Item $FilePath
        Write-Information "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -InformationAction Continue
        
        # Parse vCard with enhanced or standard parsing
        Write-Information "" -InformationAction Continue
        Write-Information "📊 Parsing vCard file..." -InformationAction Continue
        
        $contacts = if ($EnhancedParsing) {
            Import-VCardContactsEnhanced -FilePath $FilePath
        }
        else {
            Import-ContactsFromVCard -FilePath $FilePath
        }
        
        if (-not $contacts -or $contacts.Count -eq 0) {
            throw "No valid contacts found in vCard file"
        }
        
        Write-Information "✅ Parsed $($contacts.Count) contacts from vCard" -InformationAction Continue
        
        # Enhanced validation
        $validationResult = Test-VCardContactsValidation -Contacts $contacts
        Write-Information "🔍 Validation: $($validationResult.ValidCount) valid, $($validationResult.InvalidCount) invalid" -InformationAction Continue
        
        if ($validationResult.InvalidCount -gt 0) {
            Write-Warning "Found $($validationResult.InvalidCount) invalid contacts:"
            foreach ($validationError in $validationResult.ValidationErrors) {
                Write-Warning "  - Contact $($validationError.ContactIndex + 1): $($validationError.ErrorMessage)"
            }
        }
        
        # Show detailed contact info
        Write-Information "" -InformationAction Continue
        Write-Information "📋 CONTACT DETAILS:" -InformationAction Continue
        for ($i = 0; $i -lt [Math]::Min(5, $contacts.Count); $i++) {
            $contact = $contacts[$i]
            Write-Information "  Contact $($i + 1): $($contact.DisplayName)" -InformationAction Continue
            Write-Information "    Company: $($contact.CompanyName)" -InformationAction Continue
            Write-Information "    Emails: $($contact.EmailAddresses.Count)" -InformationAction Continue
            Write-Information "    Phones: Business($($contact.BusinessPhones.Count)), Mobile($($contact.MobilePhone)), Home($($contact.HomePhones.Count))" -InformationAction Continue
        }
        if ($contacts.Count -gt 5) {
            Write-Information "  ... and $($contacts.Count - 5) more contacts" -InformationAction Continue
        }
        
        if ($ValidateOnly) {
            Write-Information "" -InformationAction Continue
            Write-Information "✅ VALIDATION COMPLETE" -InformationAction Continue
            return @{
                Success          = $true
                Message          = "vCard validation completed"
                TotalContacts    = $contacts.Count
                ValidContacts    = $validationResult.ValidCount
                InvalidContacts  = $validationResult.InvalidCount
                ValidationErrors = $validationResult.ValidationErrors
            }
        }
        
        # Authentication check
        if (-not (Test-GraphConnection)) {
            throw "Microsoft Graph authentication required. Please run Initialize-GraphAuthenticationAuto first."
        }
        
        # Import using enhanced CSV import function with vCard-specific logic
        Write-Information "" -InformationAction Continue
        Write-Information "🚀 Starting vCard import..." -InformationAction Continue
        
        # Use the enhanced import function but pass our parsed vCard contacts
        $result = Import-VCardContactsToFolder -UserEmail $UserEmail -Contacts $validationResult.ValidContacts -ContactFolder $ContactFolder -DuplicateAction $DuplicateAction
        
        return $result
        
    }
    catch {
        $errorMessage = "vCard import failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        return @{
            Success       = $false
            Message       = $errorMessage
            TotalContacts = 0
            SuccessCount  = 0
            FailureCount  = 0
        }
    }
}

<#
.SYNOPSIS
    Enhanced vCard parsing with better field support
    
.DESCRIPTION
    Parses vCard files with enhanced field extraction, supporting more vCard properties,
    multiple values, and better parsing of complex fields.
    
.PARAMETER FilePath
    Path to vCard file
    
.EXAMPLE
    Import-VCardContactsEnhanced -FilePath ".\contacts.vcf"
#>
function Import-VCardContactsEnhanced {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        Write-Verbose "Enhanced parsing of vCard file: $FilePath"
        
        # Read vCard file content with proper encoding detection
        $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
        
        if ([string]::IsNullOrWhiteSpace($content)) {
            throw "vCard file is empty or unreadable"
        }
        
        # Handle different line ending formats
        $content = $content -replace "`r`n", "`n" -replace "`r", "`n"
        
        # Split into individual vCards more carefully
        $vCardBlocks = @()
        $currentBlock = ""
        $inVCard = $false
        
        foreach ($line in ($content -split "`n")) {
            $line = $line.Trim()
            
            if ($line -eq "BEGIN:VCARD") {
                $inVCard = $true
                $currentBlock = $line + "`n"
            }
            elseif ($line -eq "END:VCARD" -and $inVCard) {
                $currentBlock += $line + "`n"
                $vCardBlocks += $currentBlock
                $currentBlock = ""
                $inVCard = $false
            }
            elseif ($inVCard) {
                $currentBlock += $line + "`n"
            }
        }
        
        Write-Verbose "Found $($vCardBlocks.Count) vCard blocks for enhanced parsing"
        
        $contacts = @()
        foreach ($vCardBlock in $vCardBlocks) {
            if (-not [string]::IsNullOrWhiteSpace($vCardBlock)) {
                $contact = Convert-VCardToContactEnhanced -VCardText $vCardBlock
                if ($contact) {
                    $contacts += $contact
                }
            }
        }
        
        Write-Verbose "Enhanced parsing converted $($contacts.Count) vCards to contact objects"
        return $contacts
        
    }
    catch {
        Write-Error "Failed to parse vCard file with enhanced parsing: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Enhanced vCard to contact conversion with better field support
    
.DESCRIPTION
    Converts vCard text to contact object with enhanced parsing for more fields,
    multiple values, and better handling of complex vCard properties.
    
.PARAMETER VCardText
    vCard text content
    
.EXAMPLE
    Convert-VCardToContactEnhanced -VCardText $vCardContent
#>
function Convert-VCardToContactEnhanced {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VCardText
    )
    
    try {
        $contact = [PSCustomObject]@{
            DisplayName     = ""
            GivenName       = ""
            Surname         = ""
            MiddleName      = ""
            NamePrefix      = ""
            NameSuffix      = ""
            CompanyName     = ""
            JobTitle        = ""
            Department      = ""
            EmailAddresses  = @()
            BusinessPhones  = @()
            HomePhones      = @()
            MobilePhone     = ""
            FaxNumbers      = @()
            BusinessAddress = @{}
            HomeAddress     = @{}
            OtherAddress    = @{}
            PersonalNotes   = ""
            Birthday        = $null
            Anniversary     = $null
            WebsiteUrls     = @()
            ImAddresses     = @()
            Categories      = @()
            Source          = "Enhanced vCard Import"
            VCardVersion    = ""
            PhotoData       = $null
            CustomFields    = @{}
        }
        
        # Parse vCard lines with better handling of multi-line values
        $lines = @()
        $currentLine = ""
        
        foreach ($rawLine in ($VCardText -split "`n")) {
            $line = $rawLine.Trim()
            
            # Handle line continuation (lines starting with space or tab)
            if ($line -match "^[\s\t]" -and $currentLine -ne "") {
                $currentLine += $line.TrimStart()
            }
            else {
                if ($currentLine -ne "") {
                    $lines += $currentLine
                }
                $currentLine = $line
            }
        }
        if ($currentLine -ne "") {
            $lines += $currentLine
        }
        
        # iPhone-specific: Build mapping of item labels to types
        $iPhoneLabels = @{}
        foreach ($line in $lines) {
            if ($line -match "^(item\d+)\.X-ABLabel:(.+)$") {
                $itemRef = $matches[1]
                $label = $matches[2].Trim()
                $iPhoneLabels[$itemRef] = $label
                Write-Verbose "iPhone label mapping: $itemRef -> $label"
            }
        }
        
        foreach ($line in $lines) {
            if ($line -match "^([^:]+):(.*)$") {
                $fieldParts = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Parse field parameters (e.g., "TEL;TYPE=WORK,VOICE")
                $fieldName = ""
                $parameters = @{}
                $iPhoneItemRef = $null
                
                # Handle iPhone item references (e.g., "item1.TEL;type=pref")
                if ($fieldParts -match "^(item\d+)\.(.+)$") {
                    $iPhoneItemRef = $matches[1]
                    $fieldParts = $matches[2]
                    Write-Verbose "iPhone item detected: ${iPhoneItemRef}.$fieldParts"
                }
                
                if ($fieldParts -contains ";") {
                    $parts = $fieldParts -split ";"
                    $fieldName = $parts[0]
                    
                    for ($i = 1; $i -lt $parts.Length; $i++) {
                        if ($parts[$i] -contains "=") {
                            $paramParts = $parts[$i] -split "=", 2
                            $parameters[$paramParts[0]] = $paramParts[1]
                        }
                        else {
                            # Handle boolean parameters like "PREF"
                            $parameters[$parts[$i]] = $true
                        }
                    }
                }
                else {
                    $fieldName = $fieldParts
                }
                
                # For iPhone items, use the label mapping to determine type
                if ($iPhoneItemRef -and $iPhoneLabels.ContainsKey($iPhoneItemRef)) {
                    $iPhoneLabel = $iPhoneLabels[$iPhoneItemRef]
                    Write-Verbose "Using iPhone label for ${iPhoneItemRef}: $iPhoneLabel"
                    
                    # Map iPhone labels to standard types
                    switch -Regex ($iPhoneLabel) {
                        "Cell|Mobile|Personal Cell|Work Cell" {
                            $parameters["TYPE"] = "CELL"
                        }
                        "Work|Business" {
                            $parameters["TYPE"] = "WORK"
                        }
                        "Home|Personal" {
                            $parameters["TYPE"] = "HOME"
                        }
                        "Main" {
                            $parameters["TYPE"] = "WORK"
                            $parameters["PREF"] = $true
                        }
                    }
                }
                
                # Process fields based on enhanced parsing
                switch -Regex ($fieldName) {
                    "^VERSION$" {
                        $contact.VCardVersion = $value
                    }
                    "^FN$" {
                        $contact.DisplayName = $value
                    }
                    "^N$" {
                        # Enhanced name parsing: Surname;GivenName;MiddleName;Prefix;Suffix
                        $nameParts = $value -split ";"
                        if ($nameParts.Length -gt 0 -and $nameParts[0]) { $contact.Surname = $nameParts[0] }
                        if ($nameParts.Length -gt 1 -and $nameParts[1]) { $contact.GivenName = $nameParts[1] }
                        if ($nameParts.Length -gt 2 -and $nameParts[2]) { $contact.MiddleName = $nameParts[2] }
                        if ($nameParts.Length -gt 3 -and $nameParts[3]) { $contact.NamePrefix = $nameParts[3] }
                        if ($nameParts.Length -gt 4 -and $nameParts[4]) { $contact.NameSuffix = $nameParts[4] }
                    }
                    "^EMAIL" {
                        $emailType = "OTHER"
                        if ($parameters.ContainsKey("TYPE")) {
                            $emailType = $parameters["TYPE"].ToUpper()
                        }
                        $contact.EmailAddresses += @{ 
                            Address   = $value
                            Type      = $emailType
                            IsPrimary = $parameters.ContainsKey("PREF")
                        }
                    }
                    "^TEL" {
                        $phoneType = "OTHER"
                        if ($parameters.ContainsKey("TYPE")) {
                            $phoneType = $parameters["TYPE"].ToUpper()
                        }
                        
                        # Enhanced phone number categorization with iPhone support
                        switch -Regex ($phoneType) {
                            "WORK|BUSINESS" {
                                $contact.BusinessPhones += $value
                                Write-Verbose "Added business phone: $value"
                            }
                            "HOME|PERSONAL" {
                                $contact.HomePhones += $value
                                Write-Verbose "Added home phone: $value"
                            }
                            "CELL|MOBILE" {
                                if ([string]::IsNullOrWhiteSpace($contact.MobilePhone)) {
                                    $contact.MobilePhone = $value
                                    Write-Verbose "Added mobile phone: $value"
                                }
                                else {
                                    # Additional mobile numbers go to custom fields
                                    if (-not $contact.CustomFields.ContainsKey("AdditionalMobile")) {
                                        $contact.CustomFields["AdditionalMobile"] = @()
                                    }
                                    $contact.CustomFields["AdditionalMobile"] += $value
                                    Write-Verbose "Added additional mobile phone: $value"
                                }
                            }
                            "FAX" {
                                $contact.FaxNumbers += $value
                                Write-Verbose "Added fax number: $value"
                            }
                            default {
                                # For phones without clear type, try to guess from iPhone patterns
                                if ($iPhoneItemRef -and $iPhoneLabels.ContainsKey($iPhoneItemRef)) {
                                    $label = $iPhoneLabels[$iPhoneItemRef]
                                    if ($label -match "Cell|Mobile") {
                                        if ([string]::IsNullOrWhiteSpace($contact.MobilePhone)) {
                                            $contact.MobilePhone = $value
                                            Write-Verbose "Added mobile phone (iPhone label): $value"
                                        }
                                        else {
                                            if (-not $contact.CustomFields.ContainsKey("AdditionalMobile")) {
                                                $contact.CustomFields["AdditionalMobile"] = @()
                                            }
                                            $contact.CustomFields["AdditionalMobile"] += $value
                                            Write-Verbose "Added additional mobile phone (iPhone label): $value"
                                        }
                                    }
                                    else {
                                        # Default to business for iPhone numbers
                                        $contact.BusinessPhones += $value
                                        Write-Verbose "Added business phone (iPhone default): $value"
                                    }
                                }
                                else {
                                    # For phones without type info, check if it looks like a mobile
                                    if ($value -match "(cell|mobile)" -or $value -match "^\+?1?[\s\-\(\)]?[2-9]\d{2}[\s\-\(\)]?\d{3}[\s\-]?\d{4}$") {
                                        if ([string]::IsNullOrWhiteSpace($contact.MobilePhone)) {
                                            $contact.MobilePhone = $value
                                            Write-Verbose "Added mobile phone (pattern guess): $value"
                                        }
                                        else {
                                            if (-not $contact.CustomFields.ContainsKey("AdditionalMobile")) {
                                                $contact.CustomFields["AdditionalMobile"] = @()
                                            }
                                            $contact.CustomFields["AdditionalMobile"] += $value
                                            Write-Verbose "Added additional mobile phone (pattern guess): $value"
                                        }
                                    }
                                    else {
                                        # Default to business phone
                                        $contact.BusinessPhones += $value
                                        Write-Verbose "Added business phone (default): $value"
                                    }
                                }
                            }
                        }
                    }
                    "^ORG$" {
                        # Enhanced organization parsing
                        $orgParts = $value -split ";"
                        $contact.CompanyName = $orgParts[0]
                        if ($orgParts.Length -gt 1) {
                            $contact.Department = $orgParts[1]
                        }
                    }
                    "^TITLE$" {
                        $contact.JobTitle = $value
                    }
                    "^NOTE$" {
                        $contact.PersonalNotes = $value
                    }
                    "^BDAY$" {
                        # Enhanced birthday parsing
                        try {
                            if ($value -match "^\d{4}-\d{2}-\d{2}$") {
                                $contact.Birthday = [DateTime]::ParseExact($value, "yyyy-MM-dd", $null)
                            }
                            elseif ($value -match "^\d{4}\d{2}\d{2}$") {
                                $contact.Birthday = [DateTime]::ParseExact($value, "yyyyMMdd", $null)
                            }
                        }
                        catch {
                            Write-Verbose "Could not parse birthday: $value"
                        }
                    }
                    "^ANNIVERSARY$" {
                        # Parse anniversary date
                        try {
                            if ($value -match "^\d{4}-\d{2}-\d{2}$") {
                                $contact.Anniversary = [DateTime]::ParseExact($value, "yyyy-MM-dd", $null)
                            }
                        }
                        catch {
                            Write-Verbose "Could not parse anniversary: $value"
                        }
                    }
                    "^URL$" {
                        $contact.WebsiteUrls += $value
                    }
                    "^ADR$" {
                        # Enhanced address parsing: ;;Street;City;State;PostalCode;Country
                        $addressParts = $value -split ";"
                        $addressType = "OTHER"
                        if ($parameters.ContainsKey("TYPE")) {
                            $addressType = $parameters["TYPE"].ToUpper()
                        }
                        
                        $address = @{
                            Street     = if ($addressParts.Length -gt 2) { $addressParts[2] } else { "" }
                            City       = if ($addressParts.Length -gt 3) { $addressParts[3] } else { "" }
                            State      = if ($addressParts.Length -gt 4) { $addressParts[4] } else { "" }
                            PostalCode = if ($addressParts.Length -gt 5) { $addressParts[5] } else { "" }
                            Country    = if ($addressParts.Length -gt 6) { $addressParts[6] } else { "" }
                        }
                        
                        switch -Regex ($addressType) {
                            "WORK|BUSINESS" {
                                $contact.BusinessAddress = $address
                            }
                            "HOME|PERSONAL" {
                                $contact.HomeAddress = $address
                            }
                            default {
                                $contact.OtherAddress = $address
                            }
                        }
                    }
                    "^CATEGORIES$" {
                        $contact.Categories = $value -split ","
                    }
                    "^PHOTO$" {
                        # Handle embedded photos (base64)
                        if ($parameters.ContainsKey("ENCODING") -and $parameters["ENCODING"] -eq "BASE64") {
                            $contact.PhotoData = $value
                        }
                    }
                    "^X-" {
                        # Handle custom/extended fields
                        $customFieldName = $fieldName.Substring(2)  # Remove "X-" prefix
                        $contact.CustomFields[$customFieldName] = $value
                    }
                    default {
                        # Store unrecognized fields in custom fields
                        $contact.CustomFields[$fieldName] = $value
                        Write-Verbose "Stored unrecognized field: $fieldName = $value"
                    }
                }
            }
        }
        
        # Enhanced DisplayName fallback logic
        if ([string]::IsNullOrWhiteSpace($contact.DisplayName)) {
            $nameParts = @()
            if ($contact.NamePrefix) { $nameParts += $contact.NamePrefix }
            if ($contact.GivenName) { $nameParts += $contact.GivenName }
            if ($contact.MiddleName) { $nameParts += $contact.MiddleName }
            if ($contact.Surname) { $nameParts += $contact.Surname }
            if ($contact.NameSuffix) { $nameParts += $contact.NameSuffix }
            
            if ($nameParts.Count -gt 0) {
                $contact.DisplayName = $nameParts -join " "
            }
            elseif ($contact.CompanyName) {
                $contact.DisplayName = $contact.CompanyName
            }
            elseif ($contact.EmailAddresses.Count -gt 0) {
                $contact.DisplayName = $contact.EmailAddresses[0].Address
            }
            else {
                $contact.DisplayName = "Unknown Contact"
            }
        }
        
        return $contact
        
    }
    catch {
        Write-Error "Failed to convert vCard to contact with enhanced parsing: $($_.Exception.Message)"
        Write-Verbose "VCard content: $VCardText"
        return $null
    }
}

<#
.SYNOPSIS
    Enhanced validation for vCard contacts
    
.DESCRIPTION
    Validates vCard contacts with additional checks for vCard-specific fields.
    
.PARAMETER Contacts
    Array of contact objects to validate
    
.EXAMPLE
    Test-VCardContactsValidation -Contacts $contacts
#>
function Test-VCardContactsValidation {
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
        $warnings = @()
        
        # Required field validation
        if ([string]::IsNullOrWhiteSpace($contact.DisplayName)) {
            $errors += "DisplayName is required"
        }
        
        # Enhanced email validation
        if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) {
            foreach ($email in $contact.EmailAddresses) {
                if ($email.Address) {
                    if ($email.Address -notmatch "^[^@]+@[^@]+\.[^@]+$") {
                        $errors += "Invalid email format: $($email.Address)"
                    }
                }
                else {
                    $warnings += "Empty email address found"
                }
            }
        }
        else {
            $warnings += "No email addresses found"
        }
        
        # Phone number validation
        $totalPhones = 0
        if ($contact.BusinessPhones) { $totalPhones += $contact.BusinessPhones.Count }
        if ($contact.HomePhones) { $totalPhones += $contact.HomePhones.Count }
        if ($contact.MobilePhone) { $totalPhones += 1 }
        
        if ($totalPhones -eq 0) {
            $warnings += "No phone numbers found"
        }
        
        # Name validation
        if ([string]::IsNullOrWhiteSpace($contact.GivenName) -and [string]::IsNullOrWhiteSpace($contact.Surname)) {
            if ([string]::IsNullOrWhiteSpace($contact.CompanyName)) {
                $warnings += "No first name, last name, or company name"
            }
        }
        
        # vCard version check
        if ([string]::IsNullOrWhiteSpace($contact.VCardVersion)) {
            $warnings += "No vCard version specified"
        }
        
        if ($errors.Count -eq 0) {
            $validContacts += $contact
            if ($warnings.Count -gt 0) {
                Write-Verbose "Contact $($i + 1) warnings: $($warnings -join '; ')"
            }
        }
        else {
            $validationErrors += @{
                ContactIndex = $i
                Contact      = $contact.DisplayName
                ErrorMessage = $errors -join "; "
                Warnings     = $warnings -join "; "
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
    Import vCard contacts to specific folder with enhanced duplicate handling
    
.DESCRIPTION
    Imports validated vCard contacts to the specified folder with enhanced duplicate
    detection and handling including consolidation support.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER Contacts
    Array of validated contact objects
    
.PARAMETER ContactFolder
    Target contact folder name
    
.PARAMETER DuplicateAction
    How to handle duplicates: Skip, Merge, Overwrite, Consolidate
    
.EXAMPLE
    Import-VCardContactsToFolder -UserEmail "user@domain.com" -Contacts $contacts -ContactFolder "Vendors" -DuplicateAction "Consolidate"
#>
function Import-VCardContactsToFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [array]$Contacts,
        
        [Parameter(Mandatory = $true)]
        [string]$ContactFolder,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Skip", "Merge", "Overwrite", "Consolidate")]
        [string]$DuplicateAction = "Merge"
    )
    
    try {
        Write-Information "📥 Starting vCard contact import to folder: $ContactFolder" -InformationAction Continue
        
        # Get or create target folder
        $targetFolder = Get-OrCreateContactFolder -UserEmail $UserEmail -FolderName $ContactFolder
        Write-Information "✅ Target folder ready: $ContactFolder (ID: $($targetFolder.Id))" -InformationAction Continue
        
        # Enhanced duplicate detection across all folders
        Write-Information "🔍 Checking for duplicates across all folders..." -InformationAction Continue
        $duplicateResult = Find-DuplicateContacts -UserEmail $UserEmail -FolderId $targetFolder.Id -NewContacts $Contacts -GlobalSearch
        
        Write-Information "📊 Duplicate analysis: $($duplicateResult.UniqueContacts.Count) unique, $($duplicateResult.DuplicateCount) duplicates" -InformationAction Continue
        
        # Handle duplicates based on action
        $contactsToImport = @()
        $skippedContacts = @()
        $mergedContacts = @()
        $consolidatedContacts = @()
        
        if ($duplicateResult.DuplicateCount -gt 0) {
            switch ($DuplicateAction) {
                "Skip" {
                    Write-Information "⏭️  Skipping $($duplicateResult.DuplicateCount) duplicate contacts" -InformationAction Continue
                    $contactsToImport = $duplicateResult.UniqueContacts
                    $skippedContacts = $duplicateResult.DuplicateContacts
                }
                "Overwrite" {
                    Write-Information "🔄 Will overwrite $($duplicateResult.DuplicateCount) existing contacts" -InformationAction Continue
                    $contactsToImport = $Contacts  # Import all
                }
                "Merge" {
                    Write-Information "🤝 Merging $($duplicateResult.DuplicateCount) duplicate contacts" -InformationAction Continue
                    $contactsToImport = $duplicateResult.UniqueContacts
                    
                    # Interactive merge for duplicates
                    $mergeResult = Merge-DuplicateContacts -ExistingContacts $duplicateResult.ExistingContacts -NewContacts $duplicateResult.DuplicateContacts -InteractiveMode $true
                    $contactsToImport += $mergeResult.MergedContacts
                    $skippedContacts += $mergeResult.SkippedContacts
                    $mergedContacts += $mergeResult.UpdatedContacts
                }
                "Consolidate" {
                    Write-Information "🔗 Consolidating $($duplicateResult.DuplicateCount) duplicate contacts to target folder" -InformationAction Continue
                    $contactsToImport = $duplicateResult.UniqueContacts
                    
                    # For vCard consolidation: merge duplicates and move all to target folder
                    foreach ($newContact in $duplicateResult.DuplicateContacts) {
                        # Find existing contact
                        $email = $newContact.EmailAddresses[0].Address.ToLower()
                        $existingContact = $duplicateResult.ExistingContacts | Where-Object { 
                            $_.EmailAddresses -and $_.EmailAddresses[0].Address.ToLower() -eq $email 
                        } | Select-Object -First 1
                        
                        if ($existingContact) {
                            # Create consolidated contact with data from both
                            $consolidatedContact = Merge-VCardContactData -ExistingContact $existingContact -NewContact $newContact
                            $consolidatedContacts += @{
                                ConsolidatedContact = $consolidatedContact
                                OriginalContact     = $existingContact
                                SourceFolder        = $existingContact.SourceFolderName
                            }
                        }
                    }
                    
                    Write-Information "📋 Will consolidate $($consolidatedContacts.Count) contacts to $ContactFolder" -InformationAction Continue
                }
            }
        }
        else {
            $contactsToImport = $Contacts
        }
        
        # Import contacts
        Write-Information "" -InformationAction Continue
        Write-Information "📥 Importing $($contactsToImport.Count) contacts..." -InformationAction Continue
        
        $importResults = @{
            SuccessCount         = 0
            FailureCount         = 0
            UpdatedCount         = 0
            ConsolidatedCount    = 0
            SkippedCount         = $skippedContacts.Count
            ImportedContacts     = @()
            UpdatedContacts      = @()
            ConsolidatedContacts = @()
            Errors               = @()
        }
        
        # Import new/unique contacts
        foreach ($contact in $contactsToImport) {
            try {
                $graphContact = Convert-VCardToGraphContact -Contact $contact
                
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
                $importResults.ImportedContacts += @{
                    Contact      = $contact
                    CreatedId    = $createdContact.id
                    TargetFolder = $ContactFolder
                }
                
                Write-Verbose "✅ Imported: $($contact.DisplayName)"
                
            }
            catch {
                $importResults.FailureCount++
                $importResults.Errors += "Failed to import '$($contact.DisplayName)': $($_.Exception.Message)"
                Write-Warning "❌ Failed to import '$($contact.DisplayName)': $($_.Exception.Message)"
            }
        }
        
        # Handle merged contacts (update existing)
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
        
        # Handle consolidated contacts
        foreach ($consolidationInfo in $consolidatedContacts) {
            try {
                # Delete original contact from other folder
                if ($consolidationInfo.OriginalContact.Id -and $consolidationInfo.SourceFolder -ne $ContactFolder) {
                    Remove-ExistingContact -UserEmail $UserEmail -ContactId $consolidationInfo.OriginalContact.Id
                }
                
                # Add consolidated contact to target folder
                $graphContact = Convert-VCardToGraphContact -Contact $consolidationInfo.ConsolidatedContact
                $createdContact = Add-ContactToFolder -UserEmail $UserEmail -FolderId $targetFolder.Id -Contact $graphContact
                
                $importResults.ConsolidatedCount++
                $importResults.ConsolidatedContacts += @{
                    ConsolidatedContact = $consolidationInfo.ConsolidatedContact
                    OriginalContact     = $consolidationInfo.OriginalContact
                    SourceFolder        = $consolidationInfo.SourceFolder
                    CreatedId           = $createdContact.id
                }
                
                Write-Information "✅ Consolidated: $($consolidationInfo.ConsolidatedContact.DisplayName) from $($consolidationInfo.SourceFolder) to $ContactFolder" -InformationAction Continue
                
            }
            catch {
                $importResults.Errors += "Failed to consolidate contact '$($consolidationInfo.ConsolidatedContact.DisplayName)': $($_.Exception.Message)"
                Write-Warning "❌ Failed to consolidate contact: $($_.Exception.Message)"
            }
        }
        
        # Final summary
        Write-Information "" -InformationAction Continue
        Write-Information "🎉 VCARD IMPORT COMPLETED!" -InformationAction Continue
        Write-Information "============================" -InformationAction Continue
        Write-Information "✅ Successfully imported: $($importResults.SuccessCount) contacts" -InformationAction Continue
        Write-Information "🔄 Updated existing: $($importResults.UpdatedCount) contacts" -InformationAction Continue
        Write-Information "🔗 Consolidated: $($importResults.ConsolidatedCount) contacts" -InformationAction Continue
        Write-Information "⏭️  Skipped duplicates: $($importResults.SkippedCount) contacts" -InformationAction Continue
        Write-Information "❌ Failed imports: $($importResults.FailureCount) contacts" -InformationAction Continue
        
        if ($importResults.Errors.Count -gt 0) {
            Write-Information "" -InformationAction Continue
            Write-Information "⚠️  ERRORS:" -InformationAction Continue
            foreach ($errorMsg in $importResults.Errors) {
                Write-Warning "  • $errorMsg"
            }
        }
        
        return @{
            Success              = $true
            Message              = "vCard import completed successfully"
            TotalProcessed       = $Contacts.Count
            SuccessCount         = $importResults.SuccessCount
            UpdatedCount         = $importResults.UpdatedCount
            ConsolidatedCount    = $importResults.ConsolidatedCount
            SkippedCount         = $importResults.SkippedCount
            FailureCount         = $importResults.FailureCount
            ImportedContacts     = $importResults.ImportedContacts
            UpdatedContacts      = $importResults.UpdatedContacts
            ConsolidatedContacts = $importResults.ConsolidatedContacts
            Errors               = $importResults.Errors
        }
        
    }
    catch {
        $errorMessage = "vCard import to folder failed: $($_.Exception.Message)"
        Write-Error $errorMessage
        
        return @{
            Success        = $false
            Message        = $errorMessage
            TotalProcessed = $Contacts.Count
            SuccessCount   = 0
            FailureCount   = $Contacts.Count
        }
    }
}

<#
.SYNOPSIS
    Convert vCard contact to Microsoft Graph format with enhanced field mapping
    
.DESCRIPTION
    Converts a vCard contact object to Microsoft Graph API format with support
    for extended vCard fields and enhanced mapping.
    
.PARAMETER Contact
    vCard contact object to convert
    
.EXAMPLE
    Convert-VCardToGraphContact -Contact $vCardContact
#>
function Convert-VCardToGraphContact {
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
    
    # Handle email addresses with type information
    if ($Contact.EmailAddresses -and $Contact.EmailAddresses.Count -gt 0) {
        $graphContact.emailAddresses = @()
        foreach ($email in $Contact.EmailAddresses) {
            $graphContact.emailAddresses += @{
                address = $email.Address
                name    = $Contact.DisplayName
            }
        }
    }
    
    # Handle phone numbers with enhanced mapping
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
    
    # Handle enhanced fields
    if ($Contact.Birthday) {
        $graphContact.birthday = $Contact.Birthday.ToString("yyyy-MM-dd")
    }
    
    if ($Contact.WebsiteUrls -and $Contact.WebsiteUrls.Count -gt 0) {
        # Store in personal notes if no direct mapping
        $websiteInfo = "Websites: " + ($Contact.WebsiteUrls -join ", ")
        if ($graphContact.personalNotes) {
            $graphContact.personalNotes += "`n" + $websiteInfo
        }
        else {
            $graphContact.personalNotes = $websiteInfo
        }
    }
    
    # Handle custom fields
    if ($Contact.CustomFields -and $Contact.CustomFields.Keys.Count -gt 0) {
        $customInfo = "Custom Fields: " + (($Contact.CustomFields.Keys | ForEach-Object { "$_=$($Contact.CustomFields[$_])" }) -join ", ")
        if ($graphContact.personalNotes) {
            $graphContact.personalNotes += "`n" + $customInfo
        }
        else {
            $graphContact.personalNotes = $customInfo
        }
    }
    
    return $graphContact
}

<#
.SYNOPSIS
    Merge vCard contact data for consolidation
    
.DESCRIPTION
    Merges data from existing and new vCard contacts for consolidation operations.
    
.PARAMETER ExistingContact
    Existing contact to merge from
    
.PARAMETER NewContact
    New contact to merge from
    
.EXAMPLE
    Merge-VCardContactData -ExistingContact $existing -NewContact $new
#>
function Merge-VCardContactData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$ExistingContact,
        
        [Parameter(Mandatory = $true)]
        [PSObject]$NewContact
    )
    
    # Start with new contact data
    $merged = $NewContact.PSObject.Copy()
    
    # Merge data intelligently - prefer new data but fill gaps with existing
    if ([string]::IsNullOrWhiteSpace($merged.CompanyName) -and -not [string]::IsNullOrWhiteSpace($ExistingContact.CompanyName)) {
        $merged.CompanyName = $ExistingContact.CompanyName
    }
    
    if ([string]::IsNullOrWhiteSpace($merged.JobTitle) -and -not [string]::IsNullOrWhiteSpace($ExistingContact.JobTitle)) {
        $merged.JobTitle = $ExistingContact.JobTitle
    }
    
    if ([string]::IsNullOrWhiteSpace($merged.Department) -and -not [string]::IsNullOrWhiteSpace($ExistingContact.Department)) {
        $merged.Department = $ExistingContact.Department
    }
    
    # Merge phone numbers
    if ($ExistingContact.BusinessPhones -and $ExistingContact.BusinessPhones.Count -gt 0) {
        $merged.BusinessPhones = ($merged.BusinessPhones + $ExistingContact.BusinessPhones) | Select-Object -Unique
    }
    
    if ($ExistingContact.HomePhones -and $ExistingContact.HomePhones.Count -gt 0) {
        $merged.HomePhones = ($merged.HomePhones + $ExistingContact.HomePhones) | Select-Object -Unique
    }
    
    if ([string]::IsNullOrWhiteSpace($merged.MobilePhone) -and -not [string]::IsNullOrWhiteSpace($ExistingContact.MobilePhone)) {
        $merged.MobilePhone = $ExistingContact.MobilePhone
    }
    
    # Merge addresses
    if ((-not $merged.BusinessAddress -or $merged.BusinessAddress.Keys.Count -eq 0) -and $ExistingContact.BusinessAddress -and $ExistingContact.BusinessAddress.Keys.Count -gt 0) {
        $merged.BusinessAddress = $ExistingContact.BusinessAddress
    }
    
    if ((-not $merged.HomeAddress -or $merged.HomeAddress.Keys.Count -eq 0) -and $ExistingContact.HomeAddress -and $ExistingContact.HomeAddress.Keys.Count -gt 0) {
        $merged.HomeAddress = $ExistingContact.HomeAddress
    }
    
    # Merge notes
    if (-not [string]::IsNullOrWhiteSpace($ExistingContact.PersonalNotes)) {
        if ([string]::IsNullOrWhiteSpace($merged.PersonalNotes)) {
            $merged.PersonalNotes = $ExistingContact.PersonalNotes
        }
        else {
            $merged.PersonalNotes = $merged.PersonalNotes + "; " + $ExistingContact.PersonalNotes
        }
    }
    
    return $merged
}

<#
.SYNOPSIS
    Remove existing contact from Microsoft Graph
    
.DESCRIPTION
    Removes an existing contact from Microsoft Graph for consolidation operations.
    
.PARAMETER UserEmail
    Target user's email address
    
.PARAMETER ContactId
    ID of contact to remove
    
.EXAMPLE
    Remove-ExistingContact -UserEmail "user@domain.com" -ContactId "contact-id"
#>
function Remove-ExistingContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserEmail,
        
        [Parameter(Mandatory = $true)]
        [string]$ContactId
    )
    
    try {
        Write-Verbose "Removing existing contact: $ContactId"
        
        if (Get-Module -ListAvailable -Name "Microsoft.Graph.PersonalContacts") {
            Import-Module Microsoft.Graph.PersonalContacts -Force -Verbose:$false
            Remove-MgUserContact -UserId $UserEmail -ContactId $ContactId
        }
        else {
            # Use REST API
            $uri = "https://graph.microsoft.com/v1.0/users/$UserEmail/contacts/$ContactId"
            Invoke-MgGraphRequest -Uri $uri -Method DELETE
        }
        
        Write-Verbose "✅ Removed contact: $ContactId"
    }
    catch {
        Write-Error "Failed to remove existing contact: $($_.Exception.Message)"
        throw
    }
}

Write-Host "✅ Enhanced vCard Import Module Loaded!" -ForegroundColor Green
Write-Host "📋 Available functions:" -ForegroundColor Cyan
Write-Host "  - Import-VCardContacts" -ForegroundColor White
Write-Host "  - Import-VCardContactsEnhanced" -ForegroundColor White
Write-Host "  - Convert-VCardToContactEnhanced" -ForegroundColor White
Write-Host "  - Test-VCardContactsValidation" -ForegroundColor White
