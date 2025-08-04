<#
.SYNOPSIS
    Test-ImportOperation - Test import functionality for Import-OutlookContact
    
.DESCRIPTION
    Tests the import (BulkAdd) operation implementation to ensure it works correctly
    with CSV and vCard file parsing and validation.
    
.PARAMETER TestFile
    Test file path to use for import testing
    
.EXAMPLE
    pwsh .\test\Test-ImportOperation.ps1
    
.EXAMPLE
    pwsh .\test\Test-ImportOperation.ps1 -TestFile ".\test\sample-contacts.csv"
    
.NOTES
    Version: 1.0.0
    Tests import functionality without requiring Microsoft Graph authentication
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestFile = ""
)

Write-Information "=== Import-OutlookContact Import Operation Test ===" -InformationAction Continue
Write-Information "" -InformationAction Continue

$testResults = @()
$allTestsPassed = $true

# Helper function to add test results
function Add-TestResult {
    param($TestName, $Status, $Message, $Details = @{})
    
    $script:testResults += @{
        Test    = $TestName
        Status  = $Status
        Message = $Message
        Details = $Details
    }
    
    $icon = switch ($Status) {
        "PASS" { "✅" }
        "FAIL" { "❌" }
        "WARNING" { "⚠️ " }
        "SKIP" { "⏭️ " }
    }
    
    Write-Information "$icon $TestName`: $Message" -InformationAction Continue
    
    if ($Status -eq "FAIL") {
        $script:allTestsPassed = $false
    }
}

try {
    # Get script directory for relative paths
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $testDataPath = Join-Path $scriptRoot "test" "data"
    
    Write-Information "Test Configuration:" -InformationAction Continue
    Write-Information "  Script Root: $scriptRoot" -InformationAction Continue
    Write-Information "  Test Data Path: $testDataPath" -InformationAction Continue
    Write-Information "  Test File: $(if($TestFile) { $TestFile } else { 'Generated test data' })" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    
    # Ensure test data directory exists
    if (-not (Test-Path $testDataPath)) {
        New-Item -Path $testDataPath -ItemType Directory -Force | Out-Null
    }
    
    # Test 1: Module Import
    Write-Information "--- Testing Module Import ---" -InformationAction Continue
    
    try {
        $configModulePath = Join-Path $scriptRoot "modules" "Configuration.psm1"
        $authModulePath = Join-Path $scriptRoot "modules" "Authentication.psm1"
        $contactOpsModulePath = Join-Path $scriptRoot "modules" "ContactOperations.psm1"
        
        Import-Module $configModulePath -Force -Verbose:$false
        Import-Module $authModulePath -Force -Verbose:$false
        Import-Module $contactOpsModulePath -Force -Verbose:$false
        
        Add-TestResult "Module Import" "PASS" "All modules imported successfully"
    }
    catch {
        Add-TestResult "Module Import" "FAIL" "Failed to import modules: $($_.Exception.Message)"
    }
    
    # Test 2: Import Function Availability
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Import Functions ---" -InformationAction Continue
    
    $importFunctions = @("Import-UserContacts", "Import-ContactsFromCSV", "Import-ContactsFromVCard", "Convert-CSVRowToContact", "Convert-VCardToContact")
    foreach ($funcName in $importFunctions) {
        $func = Get-Command $funcName -ErrorAction SilentlyContinue
        if ($func) {
            Add-TestResult "Function: $funcName" "PASS" "Function is available"
        }
        else {
            Add-TestResult "Function: $funcName" "FAIL" "Function not found"
        }
    }
    
    # Test 3: Create Test CSV Data
    Write-Information "" -InformationAction Continue
    Write-Information "--- Creating Test Data ---" -InformationAction Continue
    
    try {
        # Create sample CSV test data
        $csvTestPath = Join-Path $testDataPath "test-contacts.csv"
        $csvContent = @"
DisplayName,GivenName,Surname,CompanyName,JobTitle,EmailAddress,BusinessPhone,MobilePhone
"John Smith","John","Smith","Acme Corp","Developer","john.smith@acme.com","555-123-4567","555-555-1111"
"Jane Doe","Jane","Doe","TechFlow","Manager","jane.doe@techflow.com","555-987-6543","555-555-2222"
"Bob Johnson","Bob","Johnson","Global Dynamics","Analyst","bob.johnson@global.com","555-456-7890","555-555-3333"
"@
        $csvContent | Out-File -FilePath $csvTestPath -Encoding UTF8
        
        if (Test-Path $csvTestPath) {
            Add-TestResult "CSV Test Data" "PASS" "CSV test file created: $csvTestPath"
        }
        else {
            Add-TestResult "CSV Test Data" "FAIL" "Failed to create CSV test file"
        }
        
        # Create sample vCard test data
        $vcfTestPath = Join-Path $testDataPath "test-contacts.vcf"
        $vcfContent = @"
BEGIN:VCARD
VERSION:3.0
FN:Alice Wilson
N:Wilson;Alice;;;
EMAIL:alice.wilson@example.com
TEL;TYPE=WORK:555-111-2222
TEL;TYPE=CELL:555-111-3333
ORG:Example Corp
TITLE:Senior Analyst
END:VCARD

BEGIN:VCARD
VERSION:3.0
FN:Charlie Brown
N:Brown;Charlie;;;
EMAIL:charlie.brown@demo.com
TEL;TYPE=WORK:555-444-5555
TEL;TYPE=CELL:555-444-6666
ORG:Demo Solutions
TITLE:Project Manager
END:VCARD
"@
        $vcfContent | Out-File -FilePath $vcfTestPath -Encoding UTF8
        
        if (Test-Path $vcfTestPath) {
            Add-TestResult "vCard Test Data" "PASS" "vCard test file created: $vcfTestPath"
        }
        else {
            Add-TestResult "vCard Test Data" "FAIL" "Failed to create vCard test file"
        }
        
    }
    catch {
        Add-TestResult "Test Data Creation" "FAIL" "Failed to create test data: $($_.Exception.Message)"
    }
    
    # Test 4: CSV Import Parsing
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing CSV Import Parsing ---" -InformationAction Continue
    
    try {
        if (Test-Path $csvTestPath) {
            $csvContacts = Import-ContactsFromCSV -FilePath $csvTestPath -MappingProfile "Default"
            
            if ($csvContacts -and $csvContacts.Count -gt 0) {
                Add-TestResult "CSV Parsing" "PASS" "Parsed $($csvContacts.Count) contacts from CSV"
                
                # Validate first contact
                $firstContact = $csvContacts[0]
                if ($firstContact.DisplayName -eq "John Smith" -and $firstContact.EmailAddresses[0].Address -eq "john.smith@acme.com") {
                    Add-TestResult "CSV Data Validation" "PASS" "CSV contact data correctly parsed"
                }
                else {
                    Add-TestResult "CSV Data Validation" "FAIL" "CSV contact data incorrectly parsed"
                }
            }
            else {
                Add-TestResult "CSV Parsing" "FAIL" "No contacts parsed from CSV"
            }
        }
        else {
            Add-TestResult "CSV Parsing" "SKIP" "CSV test file not available"
        }
    }
    catch {
        Add-TestResult "CSV Parsing" "FAIL" "CSV parsing failed: $($_.Exception.Message)"
    }
    
    # Test 5: vCard Import Parsing
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing vCard Import Parsing ---" -InformationAction Continue
    
    try {
        if (Test-Path $vcfTestPath) {
            $vcfContacts = Import-ContactsFromVCard -FilePath $vcfTestPath
            
            if ($vcfContacts -and $vcfContacts.Count -gt 0) {
                Add-TestResult "vCard Parsing" "PASS" "Parsed $($vcfContacts.Count) contacts from vCard"
                
                # Validate first contact
                $firstContact = $vcfContacts[0]
                if ($firstContact.DisplayName -eq "Alice Wilson" -and $firstContact.EmailAddresses[0].Address -eq "alice.wilson@example.com") {
                    Add-TestResult "vCard Data Validation" "PASS" "vCard contact data correctly parsed"
                }
                else {
                    Add-TestResult "vCard Data Validation" "FAIL" "vCard contact data incorrectly parsed"
                }
            }
            else {
                Add-TestResult "vCard Parsing" "FAIL" "No contacts parsed from vCard"
            }
        }
        else {
            Add-TestResult "vCard Parsing" "SKIP" "vCard test file not available"
        }
    }
    catch {
        Add-TestResult "vCard Parsing" "FAIL" "vCard parsing failed: $($_.Exception.Message)"
    }
    
    # Test 6: Contact Validation
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Contact Validation ---" -InformationAction Continue
    
    try {
        # Create test contacts with validation issues
        $testContacts = @(
            [PSCustomObject]@{
                DisplayName    = "Valid Contact"
                EmailAddresses = @(@{ Address = "valid@example.com" })
            },
            [PSCustomObject]@{
                DisplayName    = ""  # Missing display name
                EmailAddresses = @(@{ Address = "test@example.com" })
            },
            [PSCustomObject]@{
                DisplayName    = "Invalid Email"
                EmailAddresses = @(@{ Address = "invalid-email" })  # Invalid email
            }
        )
        
        $validationResult = Test-ContactsValidation -Contacts $testContacts
        
        if ($validationResult.ValidCount -eq 1 -and $validationResult.InvalidCount -eq 2) {
            Add-TestResult "Contact Validation" "PASS" "Validation correctly identified 1 valid and 2 invalid contacts"
        }
        else {
            Add-TestResult "Contact Validation" "FAIL" "Validation results incorrect: $($validationResult.ValidCount) valid, $($validationResult.InvalidCount) invalid"
        }
    }
    catch {
        Add-TestResult "Contact Validation" "FAIL" "Contact validation failed: $($_.Exception.Message)"
    }
    
    # Test 7: Field Mapping
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Field Mapping ---" -InformationAction Continue
    
    try {
        $csvHeaders = @("Name", "Email", "Company", "Phone")
        $mapping = Get-CSVFieldMapping -MappingProfile "Default" -CSVHeaders $csvHeaders
        
        if ($mapping -and $mapping.Keys.Count -gt 0) {
            Add-TestResult "Field Mapping" "PASS" "Field mapping created with $($mapping.Keys.Count) mappings"
            
            # Check specific mappings
            if ($mapping.DisplayName -eq "Name" -and $mapping.EmailAddress -eq "Email") {
                Add-TestResult "Mapping Accuracy" "PASS" "Field mappings are accurate"
            }
            else {
                Add-TestResult "Mapping Accuracy" "WARNING" "Some field mappings may be incorrect"
            }
        }
        else {
            Add-TestResult "Field Mapping" "FAIL" "Field mapping failed or returned empty"
        }
    }
    catch {
        Add-TestResult "Field Mapping" "FAIL" "Field mapping failed: $($_.Exception.Message)"
    }
    
    # Test 8: Graph Contact Conversion
    Write-Information "" -InformationAction Continue
    Write-Information "--- Testing Graph Contact Conversion ---" -InformationAction Continue
    
    try {
        $testContact = [PSCustomObject]@{
            DisplayName    = "Test User"
            GivenName      = "Test"
            Surname        = "User"
            CompanyName    = "Test Corp"
            EmailAddresses = @(@{ Address = "test@example.com" })
            BusinessPhones = @("555-123-4567")
        }
        
        $graphContact = Convert-ToGraphContact -Contact $testContact
        
        if ($graphContact -and $graphContact.displayName -eq "Test User" -and $graphContact.emailAddresses[0].address -eq "test@example.com") {
            Add-TestResult "Graph Conversion" "PASS" "Contact successfully converted to Graph format"
        }
        else {
            Add-TestResult "Graph Conversion" "FAIL" "Graph contact conversion failed or incorrect"
        }
    }
    catch {
        Add-TestResult "Graph Conversion" "FAIL" "Graph conversion failed: $($_.Exception.Message)"
    }
    
}
catch {
    Add-TestResult "Test Framework" "FAIL" "Test framework error: $($_.Exception.Message)"
}

# Test Summary
Write-Information "" -InformationAction Continue
Write-Information "=== Import Operation Test Summary ===" -InformationAction Continue

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq "WARNING" }).Count
$skipCount = ($testResults | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Information "Tests Run: $($testResults.Count)" -InformationAction Continue
Write-Information "Passed: $passCount" -InformationAction Continue
Write-Information "Failed: $failCount" -InformationAction Continue
Write-Information "Warnings: $warnCount" -InformationAction Continue
Write-Information "Skipped: $skipCount" -InformationAction Continue
Write-Information "" -InformationAction Continue

foreach ($result in $testResults) {
    $statusIcon = switch ($result.Status) {
        "PASS" { "✅" }
        "FAIL" { "❌" }
        "WARNING" { "⚠️ " }
        "SKIP" { "⏭️ " }
    }
    Write-Information "$statusIcon $($result.Test): $($result.Message)" -InformationAction Continue
}

Write-Information "" -InformationAction Continue

if ($allTestsPassed -and $failCount -eq 0) {
    Write-Information "🎉 All import operation tests passed!" -InformationAction Continue
    
    Write-Information "" -InformationAction Continue
    Write-Information "Next steps for complete testing:" -InformationAction Continue
    Write-Information "1. Test with main script: pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath '.\test\data\test-contacts.csv' -UserEmail 'test@example.com' -ValidateOnly `$true" -InformationAction Continue
    Write-Information "2. Authenticate to Graph: pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive" -InformationAction Continue
    Write-Information "3. Run real import: pwsh .\Import-OutlookContact.ps1 -Mode BulkAdd -CsvPath '.\test\data\test-contacts.csv' -UserEmail 'your@email.com'" -InformationAction Continue
    
    exit 0
}
else {
    Write-Error "❌ Some import operation tests failed. Please review the issues above."
    exit 1
}
