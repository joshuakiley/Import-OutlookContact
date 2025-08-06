#!/usr/bin/env pwsh

# Test specifically AMI contacts
Import-Module './modules/Authentication.psm1' -Force
Import-Module './modules/Configuration.psm1' -Force 
Import-Module './modules/ContactOperations.psm1' -Force

Write-Host "🔍 AMI CONTACTS EMAIL TEST" -ForegroundColor Yellow

try {
    Initialize-Configuration
    
    if (-not (Test-GraphConnection)) {
        Initialize-GraphAuthenticationAuto
    }
    
    $authContext = Get-AuthenticationContext
    $userEmail = $authContext.Account
    Write-Host "👤 User: $userEmail" -ForegroundColor Cyan
    
    # Get AMI contacts specifically
    Write-Host "`n📁 Getting AMI contacts..." -ForegroundColor Yellow
    $contactFolders = Get-UserContactFolders -UserEmail $userEmail
    $amiFolder = $contactFolders | Where-Object { $_.DisplayName -eq "AMI" }
    
    if ($amiFolder) {
        Write-Host "✅ AMI folder found" -ForegroundColor Green
        
        $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contactFolders/$($amiFolder.Id)/contacts"
        $amiContacts = @()
        
        do {
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            if ($response.value) {
                $amiContacts += $response.value
            }
            $uri = $response.'@odata.nextLink'
        } while ($uri)
        
        Write-Host "📊 Found $($amiContacts.Count) contacts in AMI folder" -ForegroundColor Green
        
        foreach ($contact in $amiContacts) {
            Write-Host "`n📝 Contact: $($contact.displayName)" -ForegroundColor White
            Write-Host "  🔍 Raw emailAddresses: $($contact.emailAddresses | ConvertTo-Json -Compress)" -ForegroundColor Gray
            
            if ($contact.emailAddresses) {
                Write-Host "  ✅ Has emailAddresses property" -ForegroundColor Green
                Write-Host "  📧 Type: $($contact.emailAddresses.GetType().Name)" -ForegroundColor Cyan
                Write-Host "  📧 Count: $($contact.emailAddresses.Count)" -ForegroundColor Cyan
                
                # Test the exact logic from the import script
                $emailList = @()
                if ($contact.emailAddresses -is [Array]) {
                    $emailList = $contact.emailAddresses
                }
                else {
                    $emailList = @($contact.emailAddresses)
                }
                
                Write-Host "  📧 Email list size: $($emailList.Count)" -ForegroundColor Cyan
                
                $processedEmails = $emailList | ForEach-Object { 
                    $emailAddr = if ($_ -and $_.address) { $_.address } elseif ($_ -and $_.Address) { $_.Address } else { $null }
                    if ($emailAddr -and ![string]::IsNullOrWhiteSpace($emailAddr)) { 
                        @{ Address = $emailAddr } 
                    }
                } | Where-Object { $_ -ne $null }
                
                Write-Host "  ✅ Processed emails: $($processedEmails.Count)" -ForegroundColor Green
                if ($processedEmails.Count -gt 0) {
                    $processedEmails | ForEach-Object { Write-Host "    📧 $($_.Address)" -ForegroundColor White }
                }
            }
            else {
                Write-Host "  ❌ No emailAddresses property" -ForegroundColor Red
            }
        }
        
        # Test the lookup logic
        Write-Host "`n🔍 Testing email lookup logic..." -ForegroundColor Yellow
        $existingEmails = @{}
        $debugEmailCount = 0
        $debugNoEmailCount = 0
        
        foreach ($contact in $amiContacts) {
            # Convert to same structure as import script
            $contactObj = [PSCustomObject]@{
                Id             = $contact.id
                DisplayName    = $contact.displayName
                EmailAddresses = if ($contact.emailAddresses) { 
                    $emailList = @()
                    if ($contact.emailAddresses -is [Array]) {
                        $emailList = $contact.emailAddresses
                    }
                    else {
                        $emailList = @($contact.emailAddresses)
                    }
                    
                    $validEmails = @()
                    foreach ($emailItem in $emailList) {
                        $emailAddr = if ($emailItem -and $emailItem.address) { $emailItem.address } elseif ($emailItem -and $emailItem.Address) { $emailItem.Address } else { $null }
                        if ($emailAddr -and ![string]::IsNullOrWhiteSpace($emailAddr)) { 
                            $validEmails += @{ Address = $emailAddr }
                        }
                    }
                    $validEmails
                }
                else { 
                    @() 
                }
            }
            
            # Test the lookup logic
            if ($contactObj.EmailAddresses -and $contactObj.EmailAddresses.Count -gt 0) {
                Write-Host "  ✅ ContactObj has $($contactObj.EmailAddresses.Count) emails" -ForegroundColor Green
                Write-Host "  📧 EmailAddresses array: $($contactObj.EmailAddresses | ConvertTo-Json -Compress)" -ForegroundColor Gray
                Write-Host "  📧 EmailAddresses type: $($contactObj.EmailAddresses.GetType().Name)" -ForegroundColor Gray
                
                # Try different ways to access the first item
                $firstEmail = $contactObj.EmailAddresses[0]
                Write-Host "  📧 First email via [0]: $($firstEmail | ConvertTo-Json -Compress)" -ForegroundColor Gray
                
                $firstEmailAlt = $contactObj.EmailAddresses | Select-Object -First 1
                Write-Host "  📧 First email via Select-Object: $($firstEmailAlt | ConvertTo-Json -Compress)" -ForegroundColor Gray
                
                foreach ($email in $contactObj.EmailAddresses) {
                    Write-Host "  📧 Email via foreach: $($email | ConvertTo-Json -Compress)" -ForegroundColor Gray
                    Write-Host "  📧 Email.Address: '$($email.Address)'" -ForegroundColor Gray
                    break
                }
                if ($firstEmail -and $firstEmail.Address -and ![string]::IsNullOrWhiteSpace($firstEmail.Address)) {
                    $email = $firstEmail.Address.ToLower()
                    if (-not $existingEmails.ContainsKey($email)) {
                        $existingEmails[$email] = @()
                    }
                    $existingEmails[$email] += $contactObj
                    $debugEmailCount++
                    Write-Host "  ✅ Added to lookup: $email" -ForegroundColor Green
                }
                else {
                    $debugNoEmailCount++
                    Write-Host "  ❌ First email is null or empty" -ForegroundColor Red
                }
            }
            else {
                $debugNoEmailCount++
                Write-Host "  ❌ No valid emails in contact" -ForegroundColor Red
            }
        }
        
        Write-Host "`n📊 LOOKUP RESULTS:" -ForegroundColor Cyan
        Write-Host "  📧 Indexed $($existingEmails.Keys.Count) unique email addresses" -ForegroundColor White
        Write-Host "  ✅ Contacts with emails: $debugEmailCount" -ForegroundColor Green
        Write-Host "  ❌ Contacts without emails: $debugNoEmailCount" -ForegroundColor Red
        
        if ($existingEmails.Keys.Count -gt 0) {
            Write-Host "`n📧 Indexed emails:" -ForegroundColor Cyan
            $existingEmails.Keys | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
        }
        
    }
    else {
        Write-Host "❌ AMI folder not found" -ForegroundColor Red
    }
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 Test completed!" -ForegroundColor Green
