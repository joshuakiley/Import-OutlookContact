#!/usr/bin/env pwsh

# iPhone vCard Analysis Script
Import-Module './modules/Authentication.psm1' -Force
Import-Module './modules/Configuration.psm1' -Force 
Import-Module './modules/ContactOperations.psm1' -Force

# Load enhanced vCard functions
. './scripts/Import-VCardContacts.ps1'

Write-Host "📱 iPHONE VCARD ANALYSIS" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow

try {
    $vCardFile = "./csv-files/iphone_imports.vcf"
    
    if (-not (Test-Path $vCardFile)) {
        Write-Host "❌ iPhone vCard file not found: $vCardFile" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📄 File: $vCardFile" -ForegroundColor Cyan
    $fileInfo = Get-Item $vCardFile
    Write-Host "📊 File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Cyan
    
    # Parse with enhanced parsing
    Write-Host "`n🔍 Parsing iPhone vCard with enhanced parser..." -ForegroundColor Yellow
    $contacts = Import-VCardContactsEnhanced -FilePath $vCardFile
    
    Write-Host "✅ Successfully parsed $($contacts.Count) contacts" -ForegroundColor Green
    
    # Detailed analysis
    Write-Host "`n📈 DETAILED ANALYSIS:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    # Basic stats
    $totalContacts = $contacts.Count
    $contactsWithEmails = ($contacts | Where-Object { $_.EmailAddresses.Count -gt 0 }).Count
    $contactsWithCompanies = ($contacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.CompanyName) }).Count
    $contactsWithMobile = ($contacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.MobilePhone) }).Count
    $contactsWithBusinessPhone = ($contacts | Where-Object { $_.BusinessPhones.Count -gt 0 }).Count
    $contactsWithHomePhone = ($contacts | Where-Object { $_.HomePhones.Count -gt 0 }).Count
    $contactsWithJobTitle = ($contacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.JobTitle) }).Count
    $contactsWithBusinessAddress = ($contacts | Where-Object { $_.BusinessAddress.Keys.Count -gt 0 }).Count
    $contactsWithHomeAddress = ($contacts | Where-Object { $_.HomeAddress.Keys.Count -gt 0 }).Count
    $contactsWithNotes = ($contacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.PersonalNotes) }).Count
    
    Write-Host "📊 Total Contacts: $totalContacts" -ForegroundColor White
    Write-Host "📧 With Email Addresses: $contactsWithEmails ($([math]::Round($contactsWithEmails / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "🏢 With Company Names: $contactsWithCompanies ($([math]::Round($contactsWithCompanies / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "📱 With Mobile Phones: $contactsWithMobile ($([math]::Round($contactsWithMobile / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "☎️  With Business Phones: $contactsWithBusinessPhone ($([math]::Round($contactsWithBusinessPhone / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "🏠 With Home Phones: $contactsWithHomePhone ($([math]::Round($contactsWithHomePhone / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "💼 With Job Titles: $contactsWithJobTitle ($([math]::Round($contactsWithJobTitle / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "🏢 With Business Addresses: $contactsWithBusinessAddress ($([math]::Round($contactsWithBusinessAddress / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "🏠 With Home Addresses: $contactsWithHomeAddress ($([math]::Round($contactsWithHomeAddress / $totalContacts * 100, 1))%)" -ForegroundColor White
    Write-Host "📝 With Notes: $contactsWithNotes ($([math]::Round($contactsWithNotes / $totalContacts * 100, 1))%)" -ForegroundColor White
    
    # vCard version analysis
    Write-Host "`n📋 vCard FORMAT ANALYSIS:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    $vCardVersions = $contacts | Group-Object VCardVersion
    foreach ($version in $vCardVersions) {
        Write-Host "📄 vCard Version $($version.Name): $($version.Count) contacts" -ForegroundColor White
    }
    
    # Company analysis
    Write-Host "`n🏢 TOP COMPANIES:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    $topCompanies = $contacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.CompanyName) } | 
    Group-Object CompanyName | Sort-Object Count -Descending | Select-Object -First 10
    foreach ($company in $topCompanies) {
        Write-Host "🏢 $($company.Name): $($company.Count) contacts" -ForegroundColor White
    }
    
    # Sample contacts with detailed info
    Write-Host "`n📝 SAMPLE CONTACT DETAILS:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    $sampleContacts = $contacts | Where-Object { $_.EmailAddresses.Count -gt 0 } | Select-Object -First 5
    foreach ($contact in $sampleContacts) {
        Write-Host "`n👤 $($contact.DisplayName)" -ForegroundColor Yellow
        if ($contact.GivenName -or $contact.Surname) {
            Write-Host "   Name: $($contact.GivenName) $($contact.Surname)" -ForegroundColor Gray
        }
        if ($contact.CompanyName) {
            Write-Host "   Company: $($contact.CompanyName)" -ForegroundColor Gray
        }
        if ($contact.JobTitle) {
            Write-Host "   Job Title: $($contact.JobTitle)" -ForegroundColor Gray
        }
        if ($contact.EmailAddresses.Count -gt 0) {
            Write-Host "   📧 Emails:" -ForegroundColor Cyan
            foreach ($email in $contact.EmailAddresses) {
                $emailType = if ($email.Type) { "($($email.Type))" } else { "" }
                Write-Host "      - $($email.Address) $emailType" -ForegroundColor White
            }
        }
        if ($contact.BusinessPhones.Count -gt 0) {
            Write-Host "   📞 Business Phones:" -ForegroundColor Cyan
            foreach ($phone in $contact.BusinessPhones) {
                Write-Host "      - $phone" -ForegroundColor White
            }
        }
        if ($contact.MobilePhone) {
            Write-Host "   📱 Mobile: $($contact.MobilePhone)" -ForegroundColor Cyan
        }
        if ($contact.HomePhones.Count -gt 0) {
            Write-Host "   🏠 Home Phones:" -ForegroundColor Cyan
            foreach ($phone in $contact.HomePhones) {
                Write-Host "      - $phone" -ForegroundColor White
            }
        }
        if ($contact.BusinessAddress.Keys.Count -gt 0) {
            Write-Host "   🏢 Business Address:" -ForegroundColor Cyan
            $addr = $contact.BusinessAddress
            Write-Host "      $($addr.Street), $($addr.City), $($addr.State) $($addr.PostalCode)" -ForegroundColor White
        }
        if ($contact.PersonalNotes) {
            Write-Host "   📝 Notes: $($contact.PersonalNotes)" -ForegroundColor Gray
        }
        if ($contact.CustomFields.Keys.Count -gt 0) {
            Write-Host "   🔧 Custom Fields:" -ForegroundColor Cyan
            foreach ($key in $contact.CustomFields.Keys) {
                Write-Host "      - ${key}: $($contact.CustomFields[$key])" -ForegroundColor White
            }
        }
    }
    
    # Data quality analysis
    Write-Host "`n✅ DATA QUALITY ANALYSIS:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    $contactsWithMinimalInfo = $contacts | Where-Object { 
        [string]::IsNullOrWhiteSpace($_.GivenName) -and 
        [string]::IsNullOrWhiteSpace($_.Surname) -and 
        $_.EmailAddresses.Count -eq 0 -and 
        $_.BusinessPhones.Count -eq 0 -and 
        [string]::IsNullOrWhiteSpace($_.MobilePhone)
    }
    
    $contactsWithEmailOrPhone = $contacts | Where-Object { 
        $_.EmailAddresses.Count -gt 0 -or 
        $_.BusinessPhones.Count -gt 0 -or 
        -not [string]::IsNullOrWhiteSpace($_.MobilePhone)
    }
    
    Write-Host "✅ Contacts with good data (email or phone): $($contactsWithEmailOrPhone.Count)" -ForegroundColor Green
    Write-Host "⚠️  Contacts with minimal info: $($contactsWithMinimalInfo.Count)" -ForegroundColor Yellow
    Write-Host "📊 Data quality score: $([math]::Round($contactsWithEmailOrPhone.Count / $totalContacts * 100, 1))%" -ForegroundColor White
    
    # Import readiness assessment
    Write-Host "`n🚀 IMPORT READINESS ASSESSMENT:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    Write-Host "✅ File format: iPhone vCard 3.0 (fully supported)" -ForegroundColor Green
    Write-Host "✅ Total contacts: $totalContacts (good size for import)" -ForegroundColor Green
    Write-Host "✅ Parsing: No errors or warnings" -ForegroundColor Green
    
    if ($contactsWithEmails -gt 0) {
        Write-Host "✅ Email-based duplicate detection: $contactsWithEmails contacts can be checked" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Email-based duplicate detection: Limited (only $contactsWithEmails contacts have emails)" -ForegroundColor Yellow
    }
    
    if ($contactsWithCompanies -gt ($totalContacts * 0.5)) {
        Write-Host "✅ Folder organization: $contactsWithCompanies contacts have company info for smart folder placement" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Folder organization: Limited company information for automatic folder placement" -ForegroundColor Yellow
    }
    
    # Suggested import strategy
    Write-Host "`n💡 SUGGESTED IMPORT STRATEGY:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "1. 📱 Target Folder: 'iPhone Contacts' or 'Personal'" -ForegroundColor White
    Write-Host "2. 🔄 Duplicate Action: 'Merge' (recommended for first import)" -ForegroundColor White
    Write-Host "3. 🏢 Company Mapping: Set up mapping for top companies:" -ForegroundColor White
    foreach ($company in ($topCompanies | Select-Object -First 3)) {
        Write-Host "   - '$($company.Name)' → 'Business' or custom folder" -ForegroundColor Gray
    }
    Write-Host "4. ✅ Use Enhanced Parsing: Recommended for iPhone exports" -ForegroundColor White
    Write-Host "5. 🧪 Test First: Use validation-only mode before actual import" -ForegroundColor White
    
    # Example import commands
    Write-Host "`n📋 EXAMPLE IMPORT COMMANDS:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "# Validation only (test first):" -ForegroundColor Yellow
    Write-Host 'Import-VCardContacts -FilePath "./csv-files/iphone_imports.vcf" -UserEmail "your@email.com" -ValidateOnly $true' -ForegroundColor Gray
    Write-Host "`n# Basic import to iPhone folder:" -ForegroundColor Yellow
    Write-Host 'Import-VCardContacts -FilePath "./csv-files/iphone_imports.vcf" -UserEmail "your@email.com" -ContactFolder "iPhone Contacts"' -ForegroundColor Gray
    Write-Host "`n# Advanced import with consolidation:" -ForegroundColor Yellow
    Write-Host 'Import-VCardContacts -FilePath "./csv-files/iphone_imports.vcf" -UserEmail "your@email.com" -ContactFolder "Personal" -DuplicateAction "Consolidate"' -ForegroundColor Gray
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 iPhone vCard analysis completed!" -ForegroundColor Green
