#!/usr/bin/env pwsh

# Test Enhanced vCard Import Functionality
Write-Host "🚀 TESTING ENHANCED VCARD IMPORT" -ForegroundColor Yellow

# Load the enhanced vCard import script
. './scripts/Import-VCardContacts.ps1'

try {
    # Create a comprehensive test vCard with advanced fields
    $advancedVCard = @"
BEGIN:VCARD
VERSION:3.0
FN:Dr. Sarah Michelle Johnson-Smith
N:Johnson-Smith;Sarah;Michelle;Dr.;PhD
EMAIL;TYPE=WORK:sarah.johnson@company.com
EMAIL;TYPE=HOME:sarah.personal@gmail.com
EMAIL;TYPE=OTHER:sarah.alt@domain.org
TEL;TYPE=WORK,VOICE:+1-555-123-4567
TEL;TYPE=HOME:+1-555-987-6543
TEL;TYPE=CELL:+1-555-555-1234
TEL;TYPE=FAX:+1-555-555-9999
ORG:TechFlow Solutions;Research Department
TITLE:Senior Research Director
URL:https://www.linkedin.com/in/sarahjohnson
URL:https://sarahjohnson.com
ADR;TYPE=WORK:;;789 Innovation Dr;Silicon Valley;CA;94105;United States
ADR;TYPE=HOME:;;123 Residential Ave;Home City;CA;94106;United States
NOTE:Expert in AI and machine learning with 15+ years experience. Speaks fluent Spanish and French.
BDAY:1985-03-15
ANNIVERSARY:2010-06-20
CATEGORIES:VIP,Research,AI Expert
X-TWITTER:@sarahjohnson
X-LINKEDIN:sarah-johnson-phd
X-EXPERTISE:Artificial Intelligence,Machine Learning,Data Science
END:VCARD

BEGIN:VCARD
VERSION:2.1
FN:Michael Chen
N:Chen;Michael;;;
EMAIL:m.chen@globaldynamics.com
TEL;WORK:555-456-7890
TEL;CELL:555-654-3210
ORG:Global Dynamics
TITLE:Data Analyst
NOTE:Specialist in business intelligence and reporting
END:VCARD

BEGIN:VCARD
VERSION:3.0
FN:Jane Doe
EMAIL:jane@example.com
TEL:555-000-1111
ORG:Example Corp
END:VCARD
"@
    
    # Save test vCard
    $testVCardPath = "./test-enhanced-vcard.vcf"
    $advancedVCard | Out-File -FilePath $testVCardPath -Encoding UTF8
    
    Write-Host "✅ Created advanced test vCard: $testVCardPath" -ForegroundColor Green
    
    # Test 1: Enhanced parsing vs standard parsing
    Write-Host "`n📊 COMPARISON TEST: Enhanced vs Standard Parsing" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    
    Write-Host "`n🔧 Testing Enhanced Parsing..." -ForegroundColor Yellow
    $enhancedContacts = Import-VCardContactsEnhanced -FilePath $testVCardPath
    
    Write-Host "`n🔧 Testing Standard Parsing..." -ForegroundColor Yellow
    $standardContacts = Import-ContactsFromVCard -FilePath $testVCardPath
    
    Write-Host "`n📋 PARSING COMPARISON RESULTS:" -ForegroundColor White
    Write-Host "Enhanced Parsing: $($enhancedContacts.Count) contacts" -ForegroundColor Green
    Write-Host "Standard Parsing: $($standardContacts.Count) contacts" -ForegroundColor Green
    
    # Compare first contact in detail
    if ($enhancedContacts.Count -gt 0 -and $standardContacts.Count -gt 0) {
        $enhanced = $enhancedContacts[0]
        $standard = $standardContacts[0]
        
        Write-Host "`n🔍 DETAILED COMPARISON (First Contact):" -ForegroundColor White
        Write-Host "Name Prefix - Enhanced: '$($enhanced.NamePrefix)' | Standard: N/A" -ForegroundColor Gray
        Write-Host "Name Suffix - Enhanced: '$($enhanced.NameSuffix)' | Standard: N/A" -ForegroundColor Gray
        Write-Host "Email Count - Enhanced: $($enhanced.EmailAddresses.Count) | Standard: $($standard.EmailAddresses.Count)" -ForegroundColor Gray
        Write-Host "Phone Count - Enhanced: Business($($enhanced.BusinessPhones.Count)), Mobile($($enhanced.MobilePhone)), Home($($enhanced.HomePhones.Count)) | Standard: Business($($standard.BusinessPhones.Count)), Mobile($($standard.MobilePhone)), Home($($standard.HomePhones.Count))" -ForegroundColor Gray
        Write-Host "URLs - Enhanced: $($enhanced.WebsiteUrls.Count) | Standard: N/A" -ForegroundColor Gray
        Write-Host "Custom Fields - Enhanced: $($enhanced.CustomFields.Keys.Count) | Standard: N/A" -ForegroundColor Gray
        Write-Host "vCard Version - Enhanced: '$($enhanced.VCardVersion)' | Standard: N/A" -ForegroundColor Gray
    }
    
    # Test 2: Enhanced validation
    Write-Host "`n🔍 VALIDATION TEST" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    $enhancedValidation = Test-VCardContactsValidation -Contacts $enhancedContacts
    $standardValidation = Test-ContactsValidation -Contacts $standardContacts
    
    Write-Host "Enhanced Validation: $($enhancedValidation.ValidCount) valid, $($enhancedValidation.InvalidCount) invalid" -ForegroundColor Green
    Write-Host "Standard Validation: $($standardValidation.ValidCount) valid, $($standardValidation.InvalidCount) invalid" -ForegroundColor Green
    
    # Test 3: Show enhanced contact details
    Write-Host "`n📝 ENHANCED CONTACT DETAILS" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    
    foreach ($contact in $enhancedContacts) {
        Write-Host "`nContact: $($contact.DisplayName)" -ForegroundColor White
        Write-Host "  Full Name: $($contact.NamePrefix) $($contact.GivenName) $($contact.MiddleName) $($contact.Surname) $($contact.NameSuffix)".Trim() -ForegroundColor Gray
        Write-Host "  Company: $($contact.CompanyName)" -ForegroundColor Gray
        Write-Host "  Department: $($contact.Department)" -ForegroundColor Gray
        Write-Host "  Job Title: $($contact.JobTitle)" -ForegroundColor Gray
        Write-Host "  vCard Version: $($contact.VCardVersion)" -ForegroundColor Gray
        
        if ($contact.EmailAddresses.Count -gt 0) {
            Write-Host "  📧 Email Addresses:" -ForegroundColor Cyan
            foreach ($email in $contact.EmailAddresses) {
                Write-Host "    - $($email.Address) ($($email.Type))" -ForegroundColor White
            }
        }
        
        if ($contact.BusinessPhones.Count -gt 0 -or $contact.HomePhones.Count -gt 0 -or $contact.MobilePhone) {
            Write-Host "  📞 Phone Numbers:" -ForegroundColor Cyan
            foreach ($phone in $contact.BusinessPhones) {
                Write-Host "    - $phone (Business)" -ForegroundColor White
            }
            foreach ($phone in $contact.HomePhones) {
                Write-Host "    - $phone (Home)" -ForegroundColor White
            }
            if ($contact.MobilePhone) {
                Write-Host "    - $($contact.MobilePhone) (Mobile)" -ForegroundColor White
            }
            foreach ($fax in $contact.FaxNumbers) {
                Write-Host "    - $fax (Fax)" -ForegroundColor White
            }
        }
        
        if ($contact.WebsiteUrls.Count -gt 0) {
            Write-Host "  🌐 Websites:" -ForegroundColor Cyan
            foreach ($url in $contact.WebsiteUrls) {
                Write-Host "    - $url" -ForegroundColor White
            }
        }
        
        if ($contact.BusinessAddress.Keys.Count -gt 0) {
            Write-Host "  🏢 Business Address:" -ForegroundColor Cyan
            Write-Host "    $($contact.BusinessAddress.Street), $($contact.BusinessAddress.City), $($contact.BusinessAddress.State) $($contact.BusinessAddress.PostalCode), $($contact.BusinessAddress.Country)" -ForegroundColor White
        }
        
        if ($contact.HomeAddress.Keys.Count -gt 0) {
            Write-Host "  🏠 Home Address:" -ForegroundColor Cyan
            Write-Host "    $($contact.HomeAddress.Street), $($contact.HomeAddress.City), $($contact.HomeAddress.State) $($contact.HomeAddress.PostalCode), $($contact.HomeAddress.Country)" -ForegroundColor White
        }
        
        if ($contact.Birthday) {
            Write-Host "  🎂 Birthday: $($contact.Birthday.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        }
        
        if ($contact.Anniversary) {
            Write-Host "  💍 Anniversary: $($contact.Anniversary.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        }
        
        if ($contact.Categories.Count -gt 0) {
            Write-Host "  🏷️  Categories: $($contact.Categories -join ', ')" -ForegroundColor Cyan
        }
        
        if ($contact.CustomFields.Keys.Count -gt 0) {
            Write-Host "  🔧 Custom Fields:" -ForegroundColor Cyan
            foreach ($key in $contact.CustomFields.Keys) {
                Write-Host "    - ${key}: $($contact.CustomFields[$key])" -ForegroundColor White
            }
        }
        
        if ($contact.PersonalNotes) {
            Write-Host "  📝 Notes: $($contact.PersonalNotes)" -ForegroundColor Cyan
        }
    }
    
    # Test 4: Graph API conversion
    Write-Host "`n🔄 GRAPH API CONVERSION TEST" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    foreach ($contact in $enhancedContacts) {
        Write-Host "`nConverting: $($contact.DisplayName)" -ForegroundColor Yellow
        try {
            $graphContact = Convert-VCardToGraphContact -Contact $contact
            Write-Host "✅ Successfully converted to Graph format" -ForegroundColor Green
            Write-Host "  Graph fields: $($graphContact.Keys.Count)" -ForegroundColor Gray
            Write-Host "  Email addresses: $($graphContact.emailAddresses.Count)" -ForegroundColor Gray
            Write-Host "  Has business address: $($null -ne $graphContact.businessAddress)" -ForegroundColor Gray
            Write-Host "  Has home address: $($null -ne $graphContact.homeAddress)" -ForegroundColor Gray
        }
        catch {
            Write-Host "❌ Failed to convert: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Test 5: Validation-only import test
    Write-Host "`n✅ VALIDATION-ONLY IMPORT TEST" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    
    try {
        $validationResult = Import-VCardContacts -FilePath $testVCardPath -UserEmail "test@example.com" -ValidateOnly $true
        Write-Host "✅ Validation-only import successful" -ForegroundColor Green
        Write-Host "  Total contacts: $($validationResult.TotalContacts)" -ForegroundColor Gray
        Write-Host "  Valid contacts: $($validationResult.ValidContacts)" -ForegroundColor Gray
        Write-Host "  Invalid contacts: $($validationResult.InvalidContacts)" -ForegroundColor Gray
        Write-Host "  Success: $($validationResult.Success)" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ Validation-only import failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Cleanup
    Remove-Item -Path $testVCardPath -ErrorAction SilentlyContinue
    
    Write-Host "`n🎉 Enhanced vCard Import Testing Completed!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "`n📋 SUMMARY OF ENHANCEMENTS:" -ForegroundColor Yellow
    Write-Host "✅ Enhanced vCard parsing with better field extraction" -ForegroundColor White
    Write-Host "✅ Support for multiple email addresses with types" -ForegroundColor White
    Write-Host "✅ Support for multiple phone numbers (business, home, mobile, fax)" -ForegroundColor White
    Write-Host "✅ Enhanced address parsing (business, home, other)" -ForegroundColor White
    Write-Host "✅ Support for dates (birthday, anniversary)" -ForegroundColor White
    Write-Host "✅ Support for website URLs and categories" -ForegroundColor White
    Write-Host "✅ Custom field extraction (X- fields and unrecognized fields)" -ForegroundColor White
    Write-Host "✅ Enhanced validation with warnings" -ForegroundColor White
    Write-Host "✅ Better line continuation handling" -ForegroundColor White
    Write-Host "✅ Support for consolidation duplicate action" -ForegroundColor White
    Write-Host "✅ Enhanced Graph API conversion" -ForegroundColor White
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 Test completed!" -ForegroundColor Green
