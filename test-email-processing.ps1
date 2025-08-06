#!/usr/bin/env pwsh

# Simple test to debug email processing
Write-Host "🔬 Email processing debug" -ForegroundColor Cyan

# Simulate different email address structures that might come from Microsoft Graph
$testContacts = @(
    @{
        displayName = "Test 1"
        emailAddresses = @(
            @{ address = "test1@example.com"; name = "Test 1" }
        )
    },
    @{
        displayName = "Test 2"
        emailAddresses = @(
            @{ address = "test2@example.com"; name = "Test 2" }
            @{ address = "test2alt@example.com"; name = "Test 2 Alt" }
        )
    },
    @{
        displayName = "Test 3"
        emailAddresses = @{ address = "test3@example.com"; name = "Test 3" }
    },
    @{
        displayName = "Test 4"
        emailAddresses = @()
    },
    @{
        displayName = "Test 5"
        emailAddresses = $null
    }
)

Write-Host "📧 Processing $($testContacts.Count) test contacts..." -ForegroundColor Yellow

$totalEmails = 0
$contactsWithEmails = 0
$contactsWithoutEmails = 0

foreach ($contact in $testContacts) {
    Write-Host "`n👤 $($contact.displayName)" -ForegroundColor White
    Write-Host "  Raw emailAddresses: $($contact.emailAddresses | ConvertTo-Json -Compress)" -ForegroundColor Gray
    Write-Host "  Type: $($contact.emailAddresses.GetType().Name)" -ForegroundColor Gray
    Write-Host "  IsArray: $($contact.emailAddresses -is [Array])" -ForegroundColor Gray
    
    $processedEmails = if ($contact.emailAddresses) { 
        # Ensure we always work with an array, but handle it properly
        $emailList = @()
        if ($contact.emailAddresses -is [Array]) {
            $emailList = $contact.emailAddresses
        } else {
            $emailList = @($contact.emailAddresses)
        }
        
        Write-Host "  Email list size: $($emailList.Count)" -ForegroundColor Cyan
        
        $emailList | ForEach-Object { 
            Write-Host "    Processing item: $($_ | ConvertTo-Json -Compress)" -ForegroundColor DarkGray
            $emailAddr = if ($_ -and $_.address) { $_.address } elseif ($_ -and $_.Address) { $_.Address } else { $null }
            if ($emailAddr -and ![string]::IsNullOrWhiteSpace($emailAddr)) { 
                Write-Host "    ✅ Found email: $emailAddr" -ForegroundColor Green
                @{ Address = $emailAddr } 
            } else {
                Write-Host "    ❌ No valid email found" -ForegroundColor Red
            }
        } | Where-Object { $_ -ne $null }
    } else { 
        Write-Host "  ❌ No emailAddresses field" -ForegroundColor Red
        @() 
    }
    
    Write-Host "  Final processed emails: $($processedEmails.Count)" -ForegroundColor Yellow
    if ($processedEmails.Count -gt 0) {
        $contactsWithEmails++
        $totalEmails += $processedEmails.Count
        $processedEmails | ForEach-Object { Write-Host "    - $($_.Address)" -ForegroundColor Green }
    } else {
        $contactsWithoutEmails++
    }
}

Write-Host "`n📊 SUMMARY:" -ForegroundColor Yellow
Write-Host "  Total emails found: $totalEmails" -ForegroundColor Green
Write-Host "  Contacts with emails: $contactsWithEmails" -ForegroundColor Green  
Write-Host "  Contacts without emails: $contactsWithoutEmails" -ForegroundColor Yellow
