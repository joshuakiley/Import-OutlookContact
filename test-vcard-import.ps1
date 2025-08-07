#!/usr/bin/env pwsh

# Test vCard import functionality
Import-Module './modules/Authentication.psm1' -Force
Import-Module './modules/Configuration.psm1' -Force 
Import-Module './modules/ContactOperations.psm1' -Force

Write-Host "🃏 VCARD IMPORT TEST" -ForegroundColor Yellow

try {
    Initialize-Configuration
    
    # Test 1: Test vCard parsing functionality
    Write-Host "`n📋 Testing vCard parsing..." -ForegroundColor Cyan
    
    $testVCardPath = "./test/data/test-contacts.vcf"
    if (Test-Path $testVCardPath) {
        Write-Host "✅ Test vCard file found: $testVCardPath" -ForegroundColor Green
        
        # Parse vCard using the module function
        $contacts = Import-ContactsFromVCard -FilePath $testVCardPath
        
        Write-Host "📊 Parsed $($contacts.Count) contacts from vCard" -ForegroundColor Green
        
        foreach ($contact in $contacts) {
            Write-Host "`n📝 Contact Details:" -ForegroundColor White
            Write-Host "  Name: $($contact.DisplayName)" -ForegroundColor Cyan
            Write-Host "  Given: $($contact.GivenName)" -ForegroundColor Gray
            Write-Host "  Surname: $($contact.Surname)" -ForegroundColor Gray
            Write-Host "  Company: $($contact.CompanyName)" -ForegroundColor Gray
            Write-Host "  Job Title: $($contact.JobTitle)" -ForegroundColor Gray
            Write-Host "  Emails: $($contact.EmailAddresses.Count)" -ForegroundColor Gray
            if ($contact.EmailAddresses.Count -gt 0) {
                $contact.EmailAddresses | ForEach-Object { Write-Host "    📧 $($_.Address)" -ForegroundColor White }
            }
            Write-Host "  Business Phones: $($contact.BusinessPhones.Count)" -ForegroundColor Gray
            $contact.BusinessPhones | ForEach-Object { Write-Host "    📞 $_" -ForegroundColor White }
            Write-Host "  Mobile: $($contact.MobilePhone)" -ForegroundColor Gray
            Write-Host "  Source: $($contact.Source)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "❌ Test vCard file not found: $testVCardPath" -ForegroundColor Red
    }
    
    # Test 2: Test validation
    Write-Host "`n🔍 Testing contact validation..." -ForegroundColor Cyan
    if ($contacts -and $contacts.Count -gt 0) {
        $validationResult = Test-ContactsValidation -Contacts $contacts
        Write-Host "✅ Valid contacts: $($validationResult.ValidCount)" -ForegroundColor Green
        Write-Host "❌ Invalid contacts: $($validationResult.InvalidCount)" -ForegroundColor Red
        
        if ($validationResult.InvalidCount -gt 0) {
            Write-Host "📋 Validation errors:" -ForegroundColor Yellow
            $validationResult.ValidationErrors | ForEach-Object {
                Write-Host "  Contact $($_.ContactIndex): $($_.Contact) - $($_.ErrorMessage)" -ForegroundColor Red
            }
        }
    }
    
    # Test 3: Test main import function integration
    Write-Host "`n🚀 Testing main import function..." -ForegroundColor Cyan
    try {
        # Test with ValidateOnly to avoid needing authentication
        $importResult = Import-ContactsFromFile -ImportFilePath $testVCardPath -ValidateOnly $true
        Write-Host "✅ Main import function works with vCard files" -ForegroundColor Green
        Write-Host "📊 Import result: $($importResult | ConvertTo-Json -Depth 2)" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ Main import function failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 4: Create comprehensive test vCard
    Write-Host "`n📄 Creating comprehensive test vCard..." -ForegroundColor Cyan
    $comprehensiveVCard = @"
BEGIN:VCARD
VERSION:3.0
FN:John Smith
N:Smith;John;Michael;Mr.;Jr.
EMAIL;TYPE=WORK:john.smith@company.com
EMAIL;TYPE=HOME:john.personal@gmail.com
TEL;TYPE=WORK:+1-555-123-4567
TEL;TYPE=HOME:+1-555-987-6543
TEL;TYPE=CELL:+1-555-555-1234
ORG:Acme Corporation;IT Department
TITLE:Senior Software Engineer
URL:https://www.linkedin.com/in/johnsmith
ADR;TYPE=WORK:;;123 Business St;Tech City;CA;90210;USA
ADR;TYPE=HOME:;;456 Home Ave;Hometown;CA;90211;USA
NOTE:Software engineer with 10+ years experience in cloud technologies
BDAY:1985-03-15
END:VCARD

BEGIN:VCARD
VERSION:3.0
FN:Sarah Johnson
N:Johnson;Sarah;Marie;;
EMAIL:sarah.johnson@techflow.com
TEL;TYPE=WORK:555-789-0123
TEL;TYPE=CELL:555-555-5678
ORG:TechFlow Solutions
TITLE:Project Manager
NOTE:Excellent project coordinator, handles client communications
END:VCARD

BEGIN:VCARD
VERSION:3.0
FN:Michael Chen
N:Chen;Michael;;;
EMAIL:m.chen@globaldynamics.com
TEL;TYPE=WORK:555-456-7890
TEL;TYPE=CELL:555-654-3210
ORG:Global Dynamics
TITLE:Data Analyst
NOTE:Specialist in business intelligence and reporting
END:VCARD
"@
    
    $comprehensiveVCardPath = "./test-comprehensive.vcf"
    $comprehensiveVCard | Out-File -FilePath $comprehensiveVCardPath -Encoding UTF8
    
    Write-Host "✅ Created comprehensive test vCard: $comprehensiveVCardPath" -ForegroundColor Green
    
    # Test parsing comprehensive vCard
    $comprehensiveContacts = Import-ContactsFromVCard -FilePath $comprehensiveVCardPath
    Write-Host "📊 Parsed $($comprehensiveContacts.Count) contacts from comprehensive vCard" -ForegroundColor Green
    
    # Test validation on comprehensive contacts
    $comprehensiveValidation = Test-ContactsValidation -Contacts $comprehensiveContacts
    Write-Host "✅ Comprehensive - Valid: $($comprehensiveValidation.ValidCount), Invalid: $($comprehensiveValidation.InvalidCount)" -ForegroundColor Green
    
    # Test 5: Test edge cases
    Write-Host "`n🧪 Testing edge cases..." -ForegroundColor Cyan
    
    # Empty vCard
    $emptyVCard = @"
BEGIN:VCARD
VERSION:3.0
END:VCARD
"@
    $emptyVCardPath = "./test-empty.vcf"
    $emptyVCard | Out-File -FilePath $emptyVCardPath -Encoding UTF8
    
    try {
        $emptyContacts = Import-ContactsFromVCard -FilePath $emptyVCardPath
        Write-Host "📊 Empty vCard test: Parsed $($emptyContacts.Count) contacts" -ForegroundColor Yellow
    }
    catch {
        Write-Host "❌ Empty vCard test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # vCard with minimal info
    $minimalVCard = @"
BEGIN:VCARD
VERSION:3.0
FN:Jane Doe
EMAIL:jane@example.com
END:VCARD
"@
    $minimalVCardPath = "./test-minimal.vcf"
    $minimalVCard | Out-File -FilePath $minimalVCardPath -Encoding UTF8
    
    try {
        $minimalContacts = Import-ContactsFromVCard -FilePath $minimalVCardPath
        Write-Host "📊 Minimal vCard test: Parsed $($minimalContacts.Count) contacts" -ForegroundColor Green
        $minimalValidation = Test-ContactsValidation -Contacts $minimalContacts
        Write-Host "✅ Minimal validation - Valid: $($minimalValidation.ValidCount), Invalid: $($minimalValidation.InvalidCount)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Minimal vCard test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Cleanup test files
    Remove-Item -Path $comprehensiveVCardPath -ErrorAction SilentlyContinue
    Remove-Item -Path $emptyVCardPath -ErrorAction SilentlyContinue
    Remove-Item -Path $minimalVCardPath -ErrorAction SilentlyContinue
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 vCard import test completed!" -ForegroundColor Green
