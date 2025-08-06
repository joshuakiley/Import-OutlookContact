#!/usr/bin/env pwsh

# Load modules
$moduleBase = Join-Path $PSScriptRoot "modules"
Import-Module "$moduleBase/Authentication.psm1" -Force
Import-Module "$moduleBase/Configuration.psm1" -Force
Import-Module "$moduleBase/ContactOperations.psm1" -Force

# Initialize authentication
Initialize-Authentication

# Get configuration
$config = Get-Configuration

$userEmail = (Get-MgContext).Account

Write-Host "🔍 Debug: Contact count investigation" -ForegroundColor Cyan
Write-Host "👤 User: $userEmail" -ForegroundColor Green

# Get default contacts
Write-Host "`n📊 Getting default contacts..." -ForegroundColor Yellow
$defaultContacts = Get-AllContactsInDefaultFolder -UserEmail $userEmail
Write-Host "✅ Default contacts: $($defaultContacts.Count)" -ForegroundColor Green

# Get named folder contacts  
Write-Host "`n📊 Getting named folder contacts..." -ForegroundColor Yellow
$contactFolders = Get-ContactFolders -UserEmail $userEmail
$namedFolders = $contactFolders | Where-Object { $_.DisplayName -ne "Contacts" }
Write-Host "📁 Named folders found: $($namedFolders.Count)" -ForegroundColor Cyan

$allNamedContacts = @()
foreach ($folder in $namedFolders) {
    Write-Host "  📂 $($folder.DisplayName)..." -ForegroundColor White
    $folderContacts = Get-ContactsInFolder -UserEmail $userEmail -FolderId $folder.Id
    Write-Host "    ✅ $($folderContacts.Count) contacts" -ForegroundColor Green
    $allNamedContacts += $folderContacts
}

Write-Host "`n📊 TOTALS:" -ForegroundColor Yellow
Write-Host "  Default: $($defaultContacts.Count)" -ForegroundColor White
Write-Host "  Named folders: $($allNamedContacts.Count)" -ForegroundColor White
Write-Host "  TOTAL: $($defaultContacts.Count + $allNamedContacts.Count)" -ForegroundColor Green

# Test array combining
Write-Host "`n🔬 Testing array combination..." -ForegroundColor Cyan
$allExistingContacts = @()
$allExistingContacts += $defaultContacts
$allExistingContacts += $allNamedContacts
Write-Host "  Combined array size: $($allExistingContacts.Count)" -ForegroundColor Green

# Check email processing on first few contacts
Write-Host "`n📧 Testing email processing on first 5 contacts..." -ForegroundColor Cyan
$testContacts = $allExistingContacts | Select-Object -First 5
foreach ($contact in $testContacts) {
    Write-Host "  🧑 $($contact.displayName)" -ForegroundColor White
    Write-Host "    Email raw: $($contact.emailAddresses | ConvertTo-Json -Compress)" -ForegroundColor Gray
    
    $processedEmails = if ($contact.emailAddresses) { 
        # Ensure we always work with an array, but handle it properly
        $emailList = @()
        if ($contact.emailAddresses -is [Array]) {
            $emailList = $contact.emailAddresses
        }
        else {
            $emailList = @($contact.emailAddresses)
        }
        
        $emailList | ForEach-Object { 
            $emailAddr = if ($_ -and $_.address) { $_.address } elseif ($_ -and $_.Address) { $_.Address } else { $null }
            if ($emailAddr -and ![string]::IsNullOrWhiteSpace($emailAddr)) { 
                @{ Address = $emailAddr } 
            }
        } | Where-Object { $_ -ne $null }
    }
    else { 
        @() 
    }
    
    Write-Host "    Email processed: $($processedEmails.Count) addresses" -ForegroundColor Yellow
    if ($processedEmails.Count -gt 0) {
        $processedEmails | ForEach-Object { Write-Host "      - $($_.Address)" -ForegroundColor Green }
    }
}
