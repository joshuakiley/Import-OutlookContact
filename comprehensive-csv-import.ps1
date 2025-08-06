#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$CsvFilePath,
    
    [Parameter(Mandatory = $false)]
    [string]$MappingProfile = "Default"
)

# Validate CSV file exists
if (-not (Test-Path $CsvFilePath)) {
    Write-Host "❌ ERROR: CSV file not found: $CsvFilePath" -ForegroundColor Red
    exit 1
}

# Extract folder name from CSV filename (without extension)
$csvFileName = [System.IO.Path]::GetFileNameWithoutExtension($CsvFilePath)
$folderName = $csvFileName

Write-Host "=========================================`n📁 COMPREHENSIVE CSV IMPORT WITH INTERACTIVE MERGE`n========================================" -ForegroundColor Green
Write-Host "📄 CSV File: $CsvFilePath" -ForegroundColor Cyan
Write-Host "📂 Target Folder: $folderName" -ForegroundColor Cyan

# Import modules
Import-Module './modules/Authentication.psm1' -Force -Verbose:$false
Import-Module './modules/Configuration.psm1' -Force -Verbose:$false 
Import-Module './modules/ContactOperations.psm1' -Force -Verbose:$false

try {
    Write-Host "✅ Modules loaded successfully" -ForegroundColor Green
    Initialize-Configuration -Verbose:$false
    
    # Test authentication using environment variables
    if (-not (Test-GraphConnection)) {
        Write-Host "🔐 Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Initialize-GraphAuthenticationAuto
    } else {
        Write-Host "✅ Already authenticated to Microsoft Graph" -ForegroundColor Green
    }
    
    # Get user email from authentication context
    $authContext = Get-AuthenticationContext
    $userEmail = $authContext.Account
    Write-Host "👤 Processing contacts for: $userEmail" -ForegroundColor Cyan
    
    # Step 1: Import and validate the CSV
    Write-Host "`n📊 STEP 1: Parsing CSV file..." -ForegroundColor Yellow
    $importedContacts = Import-ContactsFromCSV -FilePath $CsvFilePath -MappingProfile $MappingProfile
    
    if (-not $importedContacts -or $importedContacts.Count -eq 0) {
        throw "No valid contacts found in CSV file: $CsvFilePath"
    }
    
    Write-Host "✅ Found $($importedContacts.Count) contacts to import" -ForegroundColor Green
    
    # Show what we're importing
    Write-Host "`n📋 Contacts to import:" -ForegroundColor Cyan
    foreach ($contact in $importedContacts) {
        $email = if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) { 
            $contact.EmailAddresses[0].Address 
        } else { 
            "[NO EMAIL]" 
        }
        Write-Host "  • $($contact.DisplayName) - $email ($($contact.CompanyName))" -ForegroundColor White
    }
    
    # Step 2: Get all existing contacts from default folder (with pagination)
    Write-Host "`n🔍 STEP 2: Getting all contacts from default folder..." -ForegroundColor Yellow
    
    $allDefaultContacts = @()
    $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contacts"
    $pageCount = 0
    
    do {
        $pageCount++
        Write-Host "  📄 Loading page $pageCount..." -ForegroundColor Gray
        
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        if ($response.value -and $response.value.Count -gt 0) {
            $allDefaultContacts += $response.value
            Write-Host "    ✅ Got $($response.value.Count) contacts (total so far: $($allDefaultContacts.Count))" -ForegroundColor Gray
        }
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    Write-Host "✅ Total default contacts found: $($allDefaultContacts.Count)" -ForegroundColor Green
    
    # Step 3: Get all contacts from named folders
    Write-Host "`n📁 STEP 3: Getting contacts from named folders..." -ForegroundColor Yellow
    
    $contactFolders = Get-UserContactFolders -UserEmail $userEmail
    Write-Host "Found $($contactFolders.Count) named contact folders" -ForegroundColor Green
    
    $allNamedContacts = @()
    $folderContactCount = @{}
    
    foreach ($folder in $contactFolders) {
        Write-Host "  📂 Processing folder: $($folder.DisplayName)" -ForegroundColor Gray
        
        $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contactFolders/$($folder.Id)/contacts"
        $folderContacts = @()
        
        do {
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            if ($response.value) {
                # Add folder information to each contact
                foreach ($contact in $response.value) {
                    $contact | Add-Member -MemberType NoteProperty -Name "SourceFolderName" -Value $folder.DisplayName -Force
                    $contact | Add-Member -MemberType NoteProperty -Name "SourceFolderId" -Value $folder.Id -Force
                }
                $folderContacts += $response.value
            }
            $uri = $response.'@odata.nextLink'
        } while ($uri)
        
        $folderContactCount[$folder.DisplayName] = $folderContacts.Count
        $allNamedContacts += $folderContacts
        Write-Host "    ✅ $($folderContacts.Count) contacts" -ForegroundColor Gray
    }
    
    Write-Host "✅ Total named folder contacts: $($allNamedContacts.Count)" -ForegroundColor Green
    Write-Host "📊 Folder breakdown: $(($folderContactCount.Keys | ForEach-Object { "$_ ($($folderContactCount[$_]))" }) -join ', ')" -ForegroundColor Cyan
    
    # Step 4: Ensure target folder exists
    Write-Host "`n📁 STEP 4: Ensuring '$folderName' folder exists..." -ForegroundColor Yellow
    
    $targetFolder = $contactFolders | Where-Object { $_.DisplayName -eq $folderName }
    if (-not $targetFolder) {
        Write-Host "  📁 '$folderName' folder not found, creating it..." -ForegroundColor Yellow
        $targetFolder = Get-OrCreateContactFolder -UserEmail $userEmail -FolderName $folderName
        Write-Host "✅ '$folderName' folder created successfully (ID: $($targetFolder.Id))" -ForegroundColor Green
    } else {
        Write-Host "✅ '$folderName' folder already exists (ID: $($targetFolder.Id))" -ForegroundColor Green
    }
    
    # Step 5: Compare each contact for duplicates
    Write-Host "`n🔍 STEP 5: Checking for duplicates..." -ForegroundColor Yellow
    
    # Combine all existing contacts
    $allExistingContacts = @()
    
    # Add default contacts
    foreach ($contact in $allDefaultContacts) {
        $contactObj = [PSCustomObject]@{
            Id = $contact.id
            DisplayName = $contact.displayName
            EmailAddresses = if ($contact.emailAddresses) { 
                $contact.emailAddresses | ForEach-Object { @{ Address = $_.address } }
            } else { @() }
            CompanyName = $contact.companyName
            JobTitle = $contact.jobTitle
            BusinessPhones = if ($contact.businessPhones) { $contact.businessPhones } else { @() }
            MobilePhone = $contact.mobilePhone
            SourceFolderName = "Contacts" # Default folder
            SourceFolderId = "default"
        }
        $allExistingContacts += $contactObj
    }
    
    # Add named folder contacts
    foreach ($contact in $allNamedContacts) {
        $contactObj = [PSCustomObject]@{
            Id = $contact.id
            DisplayName = $contact.displayName
            EmailAddresses = if ($contact.emailAddresses) { 
                $contact.emailAddresses | ForEach-Object { @{ Address = $_.address } }
            } else { @() }
            CompanyName = $contact.companyName
            JobTitle = $contact.jobTitle
            BusinessPhones = if ($contact.businessPhones) { $contact.businessPhones } else { @() }
            MobilePhone = $contact.mobilePhone
            SourceFolderName = $contact.SourceFolderName
            SourceFolderId = $contact.SourceFolderId
        }
        $allExistingContacts += $contactObj
    }
    
    Write-Host "✅ Total existing contacts to check: $($allExistingContacts.Count)" -ForegroundColor Green
    
    # Build email lookup for existing contacts
    $existingEmails = @{}
    foreach ($contact in $allExistingContacts) {
        if ($contact.EmailAddresses -and $contact.EmailAddresses.Count -gt 0) {
            $firstEmail = $contact.EmailAddresses[0]
            if ($firstEmail -and $firstEmail.Address -and ![string]::IsNullOrWhiteSpace($firstEmail.Address)) {
                $email = $firstEmail.Address.ToLower()
                if (-not $existingEmails.ContainsKey($email)) {
                    $existingEmails[$email] = @()
                }
                $existingEmails[$email] += $contact
            }
        }
    }
    
    Write-Host "📧 Indexed $($existingEmails.Keys.Count) unique email addresses" -ForegroundColor Cyan
    
    # Step 6: Process each contact for import or merge
    Write-Host "`n🤝 STEP 6: Processing contacts for import/merge..." -ForegroundColor Yellow
    
    $contactsToImport = @()
    $contactsToMerge = @()
    $skippedContacts = @()
    
    foreach ($newContact in $importedContacts) {
        if (-not $newContact.EmailAddresses -or $newContact.EmailAddresses.Count -eq 0 -or 
            -not $newContact.EmailAddresses[0] -or 
            [string]::IsNullOrWhiteSpace($newContact.EmailAddresses[0].Address)) {
            Write-Host "⚠️  Skipping '$($newContact.DisplayName)' - no email address" -ForegroundColor Yellow
            $skippedContacts += $newContact
            continue
        }
        
        $newEmail = $newContact.EmailAddresses[0].Address.ToLower()
        
        if ($existingEmails.ContainsKey($newEmail)) {
            $matchingContacts = $existingEmails[$newEmail]
            Write-Host "`n🎯 DUPLICATE FOUND!" -ForegroundColor Red
            Write-Host "  📧 Email: $newEmail" -ForegroundColor Yellow
            Write-Host "  🆕 New contact: $($newContact.DisplayName)" -ForegroundColor Green
            
            foreach ($existing in $matchingContacts) {
                Write-Host "  📂 Existing: $($existing.DisplayName) in folder '$($existing.SourceFolderName)'" -ForegroundColor Cyan
            }
            
            # Ask user what to do
            Write-Host "`nWhat would you like to do?" -ForegroundColor White
            Write-Host "  [M] Merge with existing contact" -ForegroundColor Green
            Write-Host "  [S] Skip this contact" -ForegroundColor Yellow
            Write-Host "  [I] Import as new contact anyway" -ForegroundColor Blue
            
            do {
                $choice = Read-Host "Your choice (M/S/I)"
                $choice = $choice.ToUpper()
            } while ($choice -notin @('M', 'S', 'I'))
            
            switch ($choice) {
                'M' {
                    # Choose which existing contact to merge with if multiple
                    if ($matchingContacts.Count -gt 1) {
                        Write-Host "`nMultiple contacts found with this email. Which one to merge with?" -ForegroundColor Yellow
                        for ($i = 0; $i -lt $matchingContacts.Count; $i++) {
                            $existing = $matchingContacts[$i]
                            Write-Host "  [$($i + 1)] $($existing.DisplayName) in '$($existing.SourceFolderName)'" -ForegroundColor White
                        }
                        
                        do {
                            $selection = Read-Host "Select contact (1-$($matchingContacts.Count))"
                        } while ([int]$selection -lt 1 -or [int]$selection -gt $matchingContacts.Count)
                        
                        $selectedExisting = $matchingContacts[[int]$selection - 1]
                    } else {
                        $selectedExisting = $matchingContacts[0]
                    }
                    
                    $contactsToMerge += @{
                        NewContact = $newContact
                        ExistingContact = $selectedExisting
                    }
                    Write-Host "✅ Will merge with $($selectedExisting.DisplayName)" -ForegroundColor Green
                }
                'S' {
                    $skippedContacts += $newContact
                    Write-Host "⏭️  Skipped $($newContact.DisplayName)" -ForegroundColor Yellow
                }
                'I' {
                    $contactsToImport += $newContact
                    Write-Host "📥 Will import $($newContact.DisplayName) as new contact" -ForegroundColor Blue
                }
            }
        } else {
            # No duplicate found, import as new
            $contactsToImport += $newContact
            Write-Host "✅ $($newContact.DisplayName) - no duplicates, will import" -ForegroundColor Green
        }
    }
    
    # Step 7: Summary and confirmation
    Write-Host "`n📊 IMPORT SUMMARY:" -ForegroundColor Cyan
    Write-Host "  📥 Contacts to import: $($contactsToImport.Count)" -ForegroundColor Green
    Write-Host "  🤝 Contacts to merge: $($contactsToMerge.Count)" -ForegroundColor Yellow
    Write-Host "  ⏭️  Contacts skipped: $($skippedContacts.Count)" -ForegroundColor Gray
    Write-Host "  📂 Target folder: $folderName" -ForegroundColor Cyan
    
    if ($contactsToImport.Count -eq 0 -and $contactsToMerge.Count -eq 0) {
        Write-Host "`n❌ Nothing to import or merge!" -ForegroundColor Red
        return
    }
    
    Write-Host "`nProceed with import and merge operations? (Y/n)" -ForegroundAction Continue
    $confirm = Read-Host
    
    if ($confirm.ToLower() -eq 'n') {
        Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
        return
    }
    
    # Step 8: Execute imports and merges
    Write-Host "`n🚀 EXECUTING OPERATIONS..." -ForegroundColor Green
    
    $results = @{
        ImportedCount = 0
        MergedCount = 0
        FailedCount = 0
        Errors = @()
    }
    
    # Import new contacts to target folder
    if ($contactsToImport.Count -gt 0) {
        Write-Host "`n📥 Importing $($contactsToImport.Count) new contacts to '$folderName' folder..." -ForegroundColor Yellow
        
        foreach ($contact in $contactsToImport) {
            try {
                $graphContact = Convert-ToGraphContact -Contact $contact
                Add-ContactToFolder -UserEmail $userEmail -FolderId $targetFolder.Id -Contact $graphContact | Out-Null
                
                $results.ImportedCount++
                Write-Host "  ✅ Imported: $($contact.DisplayName)" -ForegroundColor Green
            }
            catch {
                $results.FailedCount++
                $errorMsg = "Failed to import '$($contact.DisplayName)': $($_.Exception.Message)"
                $results.Errors += $errorMsg
                Write-Host "  ❌ $errorMsg" -ForegroundColor Red
            }
        }
    }
    
    # Process merges
    if ($contactsToMerge.Count -gt 0) {
        Write-Host "`n🤝 Processing $($contactsToMerge.Count) merge operations..." -ForegroundColor Yellow
        
        foreach ($mergeInfo in $contactsToMerge) {
            try {
                $mergedContact = Invoke-InteractiveMerge -ExistingContact $mergeInfo.ExistingContact -NewContact $mergeInfo.NewContact
                
                if ($mergedContact) {
                    # Update the existing contact
                    Update-ExistingContact -UserEmail $userEmail -ExistingContactId $mergeInfo.ExistingContact.Id -BackupContact $mergedContact
                    $results.MergedCount++
                    Write-Host "  ✅ Merged: $($mergedContact.DisplayName)" -ForegroundColor Green
                } else {
                    Write-Host "  ⏭️  Merge cancelled for: $($mergeInfo.NewContact.DisplayName)" -ForegroundColor Yellow
                }
            }
            catch {
                $results.FailedCount++
                $errorMsg = "Failed to merge '$($mergeInfo.NewContact.DisplayName)': $($_.Exception.Message)"
                $results.Errors += $errorMsg
                Write-Host "  ❌ $errorMsg" -ForegroundColor Red
            }
        }
    }
    
    # Final results
    Write-Host "`n🎉 OPERATION COMPLETED!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "📊 FINAL RESULTS:" -ForegroundColor Cyan
    Write-Host "  ✅ Successfully imported: $($results.ImportedCount)" -ForegroundColor Green
    Write-Host "  🤝 Successfully merged: $($results.MergedCount)" -ForegroundColor Yellow
    Write-Host "  ⏭️  Skipped contacts: $($skippedContacts.Count)" -ForegroundColor Gray
    Write-Host "  ❌ Failed operations: $($results.FailedCount)" -ForegroundColor Red
    Write-Host "  📂 Target folder: $folderName" -ForegroundColor Cyan
    
    if ($results.Errors.Count -gt 0) {
        Write-Host "`n⚠️  ERRORS ENCOUNTERED:" -ForegroundColor Red
        foreach ($errorMsg in $results.Errors) {
            Write-Host "  • $errorMsg" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "`n❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 Import process completed!" -ForegroundColor Green
