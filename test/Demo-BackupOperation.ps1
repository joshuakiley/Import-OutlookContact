<#
.SYNOPSIS
    Demo-BackupOperation - Demonstrate backup functionality with mock data
    
.DESCRIPTION
    Demonstrates the backup operation using mock contact data to show
    the complete backup workflow without requiring Microsoft Graph authentication.
    
.EXAMPLE
    pwsh .\test\Demo-BackupOperation.ps1
    
.NOTES
    Version: 1.0.0
    This demo creates mock contacts to demonstrate the backup functionality
#>

Write-Information "=== Import-OutlookContact Backup Demonstration ===" -InformationAction Continue
Write-Information "" -InformationAction Continue

try {
    # Get script directory
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    
    # Import modules
    Write-Information "Loading modules..." -InformationAction Continue
    Import-Module (Join-Path $scriptRoot "modules" "ContactOperations.psm1") -Force -Verbose:$false
    
    # Create demo data
    Write-Information "Creating mock contact data for demonstration..." -InformationAction Continue
    
    $mockContacts = @(
        [PSCustomObject]@{
            Id = "mock-contact-1"
            DisplayName = "John Smith"
            GivenName = "John"
            Surname = "Smith"
            MiddleName = ""
            CompanyName = "Acme Corporation"
            JobTitle = "Senior Developer"
            Department = "Engineering"
            EmailAddresses = @(@{ Address = "john.smith@acme.com" })
            BusinessPhones = @("555-123-4567")
            HomePhones = @("555-987-6543")
            MobilePhone = "555-555-1234"
            BusinessAddress = @{
                Street = "123 Business Ave"
                City = "Tech City"
                State = "CA"
                PostalCode = "90210"
                CountryOrRegion = "United States"
            }
            HomeAddress = @{
                Street = "456 Home St"
                City = "Hometown"
                State = "CA"
                PostalCode = "90211"
                CountryOrRegion = "United States"
            }
            PersonalNotes = "Key developer for customer portal project"
            Birthday = "1985-03-15"
            CreatedDateTime = "2024-01-15T10:30:00Z"
            LastModifiedDateTime = "2024-12-01T14:22:33Z"
        },
        [PSCustomObject]@{
            Id = "mock-contact-2"
            DisplayName = "Sarah Johnson"
            GivenName = "Sarah"
            Surname = "Johnson"
            MiddleName = "Marie"
            CompanyName = "TechFlow Solutions"
            JobTitle = "Project Manager"
            Department = "Operations"
            EmailAddresses = @(@{ Address = "sarah.johnson@techflow.com" })
            BusinessPhones = @("555-789-0123")
            HomePhones = @()
            MobilePhone = "555-555-5678"
            BusinessAddress = @{
                Street = "789 Innovation Dr"
                City = "Silicon Valley"
                State = "CA"
                PostalCode = "94105"
                CountryOrRegion = "United States"
            }
            HomeAddress = $null
            PersonalNotes = "Excellent project coordinator, handles client communications"
            Birthday = "1990-07-22"
            CreatedDateTime = "2024-02-10T09:15:00Z"
            LastModifiedDateTime = "2024-11-15T16:45:12Z"
        },
        [PSCustomObject]@{
            Id = "mock-contact-3"
            DisplayName = "Michael Chen"
            GivenName = "Michael"
            Surname = "Chen"
            MiddleName = ""
            CompanyName = "Global Dynamics"
            JobTitle = "Data Analyst"
            Department = "Analytics"
            EmailAddresses = @(@{ Address = "m.chen@globaldynamics.com" })
            BusinessPhones = @("555-456-7890")
            HomePhones = @("555-654-3210")
            MobilePhone = ""
            BusinessAddress = @{
                Street = "321 Data Center Blvd"
                City = "Analytics City"
                State = "NY"
                PostalCode = "10001"
                CountryOrRegion = "United States"
            }
            HomeAddress = @{
                Street = "654 Analytics Ave"
                City = "Data Town"
                State = "NY"
                PostalCode = "10002"
                CountryOrRegion = "United States"
            }
            PersonalNotes = "Specialist in business intelligence and reporting"
            Birthday = "1988-11-08"
            CreatedDateTime = "2024-03-05T13:20:00Z"
            LastModifiedDateTime = "2024-12-20T11:30:45Z"
        }
    )
    
    Write-Information "✅ Created $($mockContacts.Count) mock contacts" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    
    # Demonstrate export functions
    $demoPath = Join-Path $scriptRoot "test" "demo-exports"
    if (-not (Test-Path $demoPath)) {
        New-Item -Path $demoPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Information "=== Demonstrating Export Functions ===" -InformationAction Continue
    
    # Test JSON export (simulate what backup would create)
    Write-Information "Testing JSON export..." -InformationAction Continue
    $jsonPath = Join-Path $demoPath "demo-contacts.json"
    $mockContacts | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Information "✅ JSON export completed: $jsonPath" -InformationAction Continue
    
    # Test vCard export
    Write-Information "Testing vCard export..." -InformationAction Continue
    $vCardPath = Join-Path $demoPath "demo-contacts.vcf"
    Export-ContactsToVCard -Contacts $mockContacts -OutputPath $vCardPath
    Write-Information "✅ vCard export completed: $vCardPath" -InformationAction Continue
    
    # Test CSV export
    Write-Information "Testing CSV export..." -InformationAction Continue
    $csvPath = Join-Path $demoPath "demo-contacts.csv"
    Export-ContactsToCSV -Contacts $mockContacts -OutputPath $csvPath
    Write-Information "✅ CSV export completed: $csvPath" -InformationAction Continue
    
    Write-Information "" -InformationAction Continue
    
    # Show file information
    Write-Information "=== Export Results ===" -InformationAction Continue
    $exportFiles = Get-ChildItem $demoPath -File
    foreach ($file in $exportFiles) {
        $sizeKB = [math]::Round($file.Length / 1024, 2)
        Write-Information "📄 $($file.Name): $sizeKB KB" -InformationAction Continue
    }
    
    Write-Information "" -InformationAction Continue
    
    # Show sample of each export format
    Write-Information "=== Sample Export Content ===" -InformationAction Continue
    
    Write-Information "" -InformationAction Continue
    Write-Information "📄 JSON Format (first contact):" -InformationAction Continue
    $jsonSample = Get-Content $jsonPath | ConvertFrom-Json | Select-Object -First 1
    Write-Information "DisplayName: $($jsonSample.DisplayName)" -InformationAction Continue
    Write-Information "Company: $($jsonSample.CompanyName)" -InformationAction Continue
    Write-Information "Email: $($jsonSample.EmailAddresses[0].Address)" -InformationAction Continue
    
    Write-Information "" -InformationAction Continue
    Write-Information "📄 vCard Format (first few lines):" -InformationAction Continue
    $vCardLines = Get-Content $vCardPath | Select-Object -First 8
    $vCardLines | ForEach-Object { Write-Information $_ -InformationAction Continue }
    
    Write-Information "" -InformationAction Continue
    Write-Information "📄 CSV Format (headers and first row):" -InformationAction Continue
    $csvLines = Get-Content $csvPath | Select-Object -First 2
    $csvLines | ForEach-Object { Write-Information $_ -InformationAction Continue }
    
    Write-Information "" -InformationAction Continue
    
    # Simulate backup metadata
    Write-Information "=== Simulated Backup Metadata ===" -InformationAction Continue
    $backupMetadata = @{
        UserEmail = "demo@example.com"
        BackupDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        BackupFormat = "Multiple"
        IncludePhotos = $false
        ContactFolder = "All Folders"
        Version = "1.0.0"
        TotalContacts = $mockContacts.Count
        ContactFolders = @(
            @{ Id = "folder-1"; DisplayName = "Contacts"; TotalItems = 2 },
            @{ Id = "folder-2"; DisplayName = "Business Contacts"; TotalItems = 1 }
        )
        BackupFiles = @(
            @{ FileName = "demo-contacts.json"; FolderName = "All"; ContactCount = 3; FileSize = (Get-Item $jsonPath).Length },
            @{ FileName = "demo-contacts.vcf"; FolderName = "All"; ContactCount = 3; FileSize = (Get-Item $vCardPath).Length },
            @{ FileName = "demo-contacts.csv"; FolderName = "All"; ContactCount = 3; FileSize = (Get-Item $csvPath).Length }
        )
    }
    
    $metadataPath = Join-Path $demoPath "backup-metadata.json"
    $backupMetadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataPath -Encoding UTF8
    
    Write-Information "User: $($backupMetadata.UserEmail)" -InformationAction Continue
    Write-Information "Backup Date: $($backupMetadata.BackupDate)" -InformationAction Continue
    Write-Information "Total Contacts: $($backupMetadata.TotalContacts)" -InformationAction Continue
    Write-Information "Contact Folders: $($backupMetadata.ContactFolders.Count)" -InformationAction Continue
    Write-Information "Backup Files: $($backupMetadata.BackupFiles.Count)" -InformationAction Continue
    
    Write-Information "" -InformationAction Continue
    Write-Information "🎉 Backup demonstration completed successfully!" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    Write-Information "📁 Demo files created in: $demoPath" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    Write-Information "Next steps to test with real data:" -InformationAction Continue
    Write-Information "1. Configure Azure AD: pwsh .\scripts\Setup-Environment.ps1 -Interactive" -InformationAction Continue
    Write-Information "2. Test authentication: pwsh .\scripts\Test-Authentication.ps1 -TestMode Interactive" -InformationAction Continue
    Write-Information "3. Run real backup: pwsh .\Import-OutlookContact.ps1 -Mode Backup -UserEmail 'your@email.com'" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    
}
catch {
    Write-Error "Demo failed: $($_.Exception.Message)"
    exit 1
}
