#!/usr/bin/env pwsh

Write-Host "🔍 EMAIL STRUCTURE DEBUG" -ForegroundColor Yellow

# Import modules
Import-Module './modules/Authentication.psm1' -Force -Verbose:$false
Import-Module './modules/Configuration.psm1' -Force -Verbose:$false 

try {
    Initialize-Configuration -Verbose:$false
    
    if (-not (Test-GraphConnection)) {
        Initialize-GraphAuthenticationAuto
    }
    
    $authContext = Get-AuthenticationContext
    $userEmail = $authContext.Account
    Write-Host "👤 User: $userEmail" -ForegroundColor Cyan
    
    # Get first 10 default contacts to analyze their email structure
    Write-Host "`n📁 Analyzing first 10 default contacts..." -ForegroundColor Yellow
    $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contacts?\$top=10"
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET
    
    foreach ($contact in $response.value) {
        Write-Host "`n  👤 Contact: $($contact.displayName)" -ForegroundColor Cyan
        
        if ($contact.emailAddresses) {
            Write-Host "    📧 emailAddresses exists" -ForegroundColor Green
            Write-Host "    📧 Type: $($contact.emailAddresses.GetType().Name)" -ForegroundColor Gray
            
            if ($contact.emailAddresses -is [Array]) {
                Write-Host "    📧 Is Array with $($contact.emailAddresses.Count) items" -ForegroundColor Green
                foreach ($email in $contact.emailAddresses) {
                    Write-Host "      ✉️ Email: $($email | ConvertTo-Json -Compress)" -ForegroundColor White
                }
            }
            else {
                Write-Host "    📧 Is Single Object" -ForegroundColor Yellow
                Write-Host "      ✉️ Email: $($contact.emailAddresses | ConvertTo-Json -Compress)" -ForegroundColor White
            }
            
            # Test our processing logic
            Write-Host "    🔬 Testing our processing..." -ForegroundColor Magenta
            $emailArray = if ($contact.emailAddresses -is [Array]) { $contact.emailAddresses } else { @($contact.emailAddresses) }
            Write-Host "      📊 Array size after processing: $($emailArray.Count)" -ForegroundColor Gray
            
            # Debug each element in the array
            for ($i = 0; $i -lt $emailArray.Count; $i++) {
                Write-Host "        [$i] Type: $($emailArray[$i].GetType().Name) | Value: $($emailArray[$i] | ConvertTo-Json -Compress)" -ForegroundColor Cyan
            }
            
            $processed = $emailArray | ForEach-Object { 
                $emailAddr = if ($_.address) { $_.address } elseif ($_.Address) { $_.Address } else { $null }
                Write-Host "        Processing: emailAddr='$emailAddr'" -ForegroundColor DarkCyan
                if ($emailAddr) { @{ Address = $emailAddr } } else { $null }
            } | Where-Object { $_ -ne $null }
            
            Write-Host "      ✅ Processed emails: $($processed.Count)" -ForegroundColor Green
            if ($processed.Count -gt 0) {
                Write-Host "      📍 First processed: $($processed[0] | ConvertTo-Json -Compress)" -ForegroundColor Yellow
            }
            
        }
        else {
            Write-Host "    ❌ No emailAddresses property" -ForegroundColor Red
        }
    }
    
    Write-Host "`n📁 Analyzing first 5 AMI folder contacts..." -ForegroundColor Yellow
    
    # Get AMI folder  
    $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contactFolders"
    $foldersResponse = Invoke-MgGraphRequest -Uri $uri -Method GET
    $amiFolder = $foldersResponse.value | Where-Object { $_.displayName -eq "AMI" }
    
    if ($amiFolder) {
        $uri = "https://graph.microsoft.com/v1.0/users/$userEmail/contactFolders/$($amiFolder.Id)/contacts?\$top=5"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        
        foreach ($contact in $response.value) {
            Write-Host "`n  👤 AMI Contact: $($contact.displayName)" -ForegroundColor Cyan
            
            if ($contact.emailAddresses) {
                Write-Host "    📧 emailAddresses exists" -ForegroundColor Green
                Write-Host "    📧 Type: $($contact.emailAddresses.GetType().Name)" -ForegroundColor Gray
                
                if ($contact.emailAddresses -is [Array]) {
                    Write-Host "    📧 Is Array with $($contact.emailAddresses.Count) items" -ForegroundColor Green
                    foreach ($email in $contact.emailAddresses) {
                        Write-Host "      ✉️ Email: $($email | ConvertTo-Json -Compress)" -ForegroundColor White
                    }
                }
                else {
                    Write-Host "    📧 Is Single Object" -ForegroundColor Yellow
                    Write-Host "      ✉️ Email: $($contact.emailAddresses | ConvertTo-Json -Compress)" -ForegroundColor White
                }
                
                # Test our processing logic
                Write-Host "    🔬 Testing our processing..." -ForegroundColor Magenta
                $emailArray = if ($contact.emailAddresses -is [Array]) { $contact.emailAddresses } else { @($contact.emailAddresses) }
                Write-Host "      📊 Array size after processing: $($emailArray.Count)" -ForegroundColor Gray
                
                $processed = $emailArray | ForEach-Object { 
                    $emailAddr = if ($_.address) { $_.address } elseif ($_.Address) { $_.Address } else { $null }
                    if ($emailAddr) { @{ Address = $emailAddr } } else { $null }
                } | Where-Object { $_ -ne $null }
                
                Write-Host "      ✅ Processed emails: $($processed.Count)" -ForegroundColor Green
                if ($processed.Count -gt 0) {
                    Write-Host "      📍 First processed: $($processed[0] | ConvertTo-Json -Compress)" -ForegroundColor Yellow
                }
                
            }
            else {
                Write-Host "    ❌ No emailAddresses property" -ForegroundColor Red
            }
        }
    }
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 Email structure analysis completed!" -ForegroundColor Green
