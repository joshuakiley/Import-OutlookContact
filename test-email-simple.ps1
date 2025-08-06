#!/usr/bin/env pwsh

# Simple email processing test
Import-Module './modules/Authentication.psm1' -Force
Import-Module './modules/Configuration.psm1' -Force 
Import-Module './modules/ContactOperations.psm1' -Force

Write-Host "🔍 EMAIL PROCESSING TEST" -ForegroundColor Yellow

try {
    Initialize-Configuration
    
    if (-not (Test-GraphConnection)) {
        Initialize-GraphAuthenticationAuto
    }
    
    $authContext = Get-AuthenticationContext
    $userEmail = $authContext.Account
    Write-Host "👤 User: $userEmail" -ForegroundColor Cyan
    
    # Get just a few contacts from default folder to test
    Write-Host "`n📊 Getting first 5 default contacts..." -ForegroundColor Yellow
    
    $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contacts?`$top=5"
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET
    $testContacts = $response.value
    
    Write-Host "✅ Got $($testContacts.Count) test contacts" -ForegroundColor Green
    
    foreach ($contact in $testContacts) {
        Write-Host "`n📝 Contact: $($contact.displayName)" -ForegroundColor White
        Write-Host "  🔍 Raw emailAddresses: $($contact.emailAddresses | ConvertTo-Json -Compress)" -ForegroundColor Gray
        
        # Test our processing logic
        $processedEmails = if ($contact.emailAddresses) { 
            # Ensure we always work with an array, but handle it properly
            $emailList = @()
            if ($contact.emailAddresses -is [Array]) {
                $emailList = $contact.emailAddresses
            }
            else {
                $emailList = @($contact.emailAddresses)
            }
            
            Write-Host "  📧 Email list size after conversion: $($emailList.Count)" -ForegroundColor Cyan
            
            $emailList | ForEach-Object { 
                Write-Host "    🔸 Processing email item: $($_ | ConvertTo-Json -Compress)" -ForegroundColor Gray
                $emailAddr = if ($_ -and $_.address) { $_.address } elseif ($_ -and $_.Address) { $_.Address } else { $null }
                Write-Host "    🔸 Extracted address: '$emailAddr'" -ForegroundColor Gray
                if ($emailAddr -and ![string]::IsNullOrWhiteSpace($emailAddr)) { 
                    Write-Host "    ✅ Valid email: '$emailAddr'" -ForegroundColor Green
                    @{ Address = $emailAddr } 
                }
                else {
                    Write-Host "    ❌ Invalid/empty email" -ForegroundColor Red
                    $null
                }
            } | Where-Object { $_ -ne $null }
        }
        else { 
            @() 
        }
        
        Write-Host "  ✅ Final processed emails: $($processedEmails.Count)" -ForegroundColor Green
        if ($processedEmails.Count -gt 0) {
            $processedEmails | ForEach-Object { Write-Host "    📧 $($_.Address)" -ForegroundColor White }
        }
    }
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 Test completed!" -ForegroundColor Green
