#!/usr/bin/env pwsh

# Test all fields in iPhone vCard
Import-Module './modules/Authentication.psm1' -Force
Import-Module './modules/Configuration.psm1' -Force 
Import-Module './modules/ContactOperations.psm1' -Force

# Load enhanced vCard functions
. './scripts/Import-VCardContacts.ps1'

Write-Host "🔍 ALL FIELDS ANALYSIS - iPhone vCard" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

try {
    $vCardFile = "./csv-files/iphone_imports.vcf"
    
    if (-not (Test-Path $vCardFile)) {
        Write-Host "❌ iPhone vCard file not found: $vCardFile" -ForegroundColor Red
        exit 1
    }
    
    # Parse with enhanced parsing
    Write-Host "🔍 Parsing iPhone vCard with enhanced parser..." -ForegroundColor Yellow
    $contacts = Import-VCardContactsEnhanced -FilePath $vCardFile
    
    Write-Host "✅ Successfully parsed $($contacts.Count) contacts" -ForegroundColor Green
    
    # Find Aneta Orlowska specifically
    $anetaContact = $contacts | Where-Object { $_.DisplayName -like "*Aneta*" -or $_.GivenName -like "*Aneta*" }
    
    if ($anetaContact) {
        Write-Host "`n👤 ANETA ORLOWSKA - ALL FIELDS:" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        
        $contact = $anetaContact
        $allProperties = $contact.PSObject.Properties | Sort-Object Name
        
        foreach ($prop in $allProperties) {
            $value = $prop.Value
            $name = $prop.Name
            
            Write-Host "`n📋 $name`: " -ForegroundColor Yellow -NoNewline
            
            if ($value -eq $null) {
                Write-Host "null" -ForegroundColor Gray
            }
            elseif ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                Write-Host "(empty string)" -ForegroundColor Gray
            }
            elseif ($value -is [array]) {
                if ($value.Count -eq 0) {
                    Write-Host "(empty array)" -ForegroundColor Gray
                }
                else {
                    Write-Host "Array[$($value.Count)]:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $value.Count; $i++) {
                        $item = $value[$i]
                        if ($item -is [hashtable] -or $item.GetType().Name -eq "PSCustomObject") {
                            Write-Host "  [$i]: " -ForegroundColor White -NoNewline
                            Write-Host ($item | ConvertTo-Json -Compress) -ForegroundColor White
                        }
                        else {
                            Write-Host "  [$i]: '$item'" -ForegroundColor White
                        }
                    }
                }
            }
            elseif ($value -is [hashtable]) {
                if ($value.Keys.Count -eq 0) {
                    Write-Host "(empty hashtable)" -ForegroundColor Gray
                }
                else {
                    Write-Host "Hashtable[$($value.Keys.Count)]:" -ForegroundColor Cyan
                    foreach ($key in ($value.Keys | Sort-Object)) {
                        Write-Host "  $key`: '$($value[$key])'" -ForegroundColor White
                    }
                }
            }
            elseif ($value.GetType().Name -eq "PSCustomObject") {
                Write-Host "Object:" -ForegroundColor Cyan
                $value.PSObject.Properties | ForEach-Object {
                    Write-Host "  $($_.Name): '$($_.Value)'" -ForegroundColor White
                }
            }
            elseif ($value -is [DateTime]) {
                Write-Host "'$($value.ToString('yyyy-MM-dd HH:mm:ss'))'" -ForegroundColor Green
            }
            else {
                Write-Host "'$value'" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "❌ Aneta Orlowska not found" -ForegroundColor Red
    }
    
    # Also show a few other contacts for comparison
    Write-Host "`n🔍 OTHER CONTACTS - FIELD SUMMARY:" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    
    $sampleContacts = $contacts | Where-Object { 
        -not [string]::IsNullOrWhiteSpace($_.DisplayName) 
    } | Select-Object -First 5
    
    foreach ($contact in $sampleContacts) {
        Write-Host "`n👤 $($contact.DisplayName)" -ForegroundColor Yellow
        
        # Core identification fields
        Write-Host "  🆔 Core Info:" -ForegroundColor Cyan
        Write-Host "    DisplayName: '$($contact.DisplayName)'" -ForegroundColor White
        Write-Host "    GivenName: '$($contact.GivenName)'" -ForegroundColor White
        Write-Host "    Surname: '$($contact.Surname)'" -ForegroundColor White
        Write-Host "    MiddleName: '$($contact.MiddleName)'" -ForegroundColor White
        Write-Host "    NamePrefix: '$($contact.NamePrefix)'" -ForegroundColor White
        Write-Host "    NameSuffix: '$($contact.NameSuffix)'" -ForegroundColor White
        
        # Organization fields
        Write-Host "  🏢 Organization:" -ForegroundColor Cyan
        Write-Host "    CompanyName: '$($contact.CompanyName)'" -ForegroundColor White
        Write-Host "    JobTitle: '$($contact.JobTitle)'" -ForegroundColor White
        Write-Host "    Department: '$($contact.Department)'" -ForegroundColor White
        
        # Contact fields
        Write-Host "  📞 Contact Info:" -ForegroundColor Cyan
        Write-Host "    EmailAddresses: $($contact.EmailAddresses.Count) items" -ForegroundColor White
        if ($contact.EmailAddresses.Count -gt 0) {
            $contact.EmailAddresses | ForEach-Object { 
                Write-Host "      - $($_.Address) ($($_.Type))" -ForegroundColor Gray 
            }
        }
        Write-Host "    BusinessPhones: $($contact.BusinessPhones.Count) items" -ForegroundColor White
        $contact.BusinessPhones | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
        Write-Host "    MobilePhone: '$($contact.MobilePhone)'" -ForegroundColor White
        Write-Host "    HomePhones: $($contact.HomePhones.Count) items" -ForegroundColor White
        $contact.HomePhones | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
        Write-Host "    FaxNumbers: $($contact.FaxNumbers.Count) items" -ForegroundColor White
        $contact.FaxNumbers | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
        
        # Address fields
        Write-Host "  🏠 Addresses:" -ForegroundColor Cyan
        Write-Host "    BusinessAddress: $($contact.BusinessAddress.Keys.Count) fields" -ForegroundColor White
        if ($contact.BusinessAddress.Keys.Count -gt 0) {
            foreach ($key in $contact.BusinessAddress.Keys) {
                Write-Host "      $key`: '$($contact.BusinessAddress[$key])'" -ForegroundColor Gray
            }
        }
        Write-Host "    HomeAddress: $($contact.HomeAddress.Keys.Count) fields" -ForegroundColor White
        if ($contact.HomeAddress.Keys.Count -gt 0) {
            foreach ($key in $contact.HomeAddress.Keys) {
                Write-Host "      $key`: '$($contact.HomeAddress[$key])'" -ForegroundColor Gray
            }
        }
        Write-Host "    OtherAddress: $($contact.OtherAddress.Keys.Count) fields" -ForegroundColor White
        if ($contact.OtherAddress.Keys.Count -gt 0) {
            foreach ($key in $contact.OtherAddress.Keys) {
                Write-Host "      $key`: '$($contact.OtherAddress[$key])'" -ForegroundColor Gray
            }
        }
        
        # Additional fields
        Write-Host "  📅 Dates:" -ForegroundColor Cyan
        Write-Host "    Birthday: $($contact.Birthday)" -ForegroundColor White
        Write-Host "    Anniversary: $($contact.Anniversary)" -ForegroundColor White
        
        Write-Host "  🌐 Other:" -ForegroundColor Cyan
        Write-Host "    WebsiteUrls: $($contact.WebsiteUrls.Count) items" -ForegroundColor White
        $contact.WebsiteUrls | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
        Write-Host "    ImAddresses: $($contact.ImAddresses.Count) items" -ForegroundColor White
        $contact.ImAddresses | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
        Write-Host "    Categories: $($contact.Categories.Count) items" -ForegroundColor White
        $contact.Categories | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
        Write-Host "    PersonalNotes: '$($contact.PersonalNotes)'" -ForegroundColor White
        Write-Host "    Source: '$($contact.Source)'" -ForegroundColor White
        Write-Host "    VCardVersion: '$($contact.VCardVersion)'" -ForegroundColor White
        Write-Host "    PhotoData: $(if ($contact.PhotoData) { "$(($contact.PhotoData).Length) chars" } else { "null" })" -ForegroundColor White
        
        # Custom fields
        Write-Host "  🔧 Custom Fields: $($contact.CustomFields.Keys.Count) items" -ForegroundColor Cyan
        if ($contact.CustomFields.Keys.Count -gt 0) {
            foreach ($key in ($contact.CustomFields.Keys | Sort-Object)) {
                $customValue = $contact.CustomFields[$key]
                if ($customValue -is [array]) {
                    Write-Host "    $key`: Array[$($customValue.Count)]" -ForegroundColor Gray
                    $customValue | ForEach-Object { Write-Host "      - $_" -ForegroundColor DarkGray }
                }
                else {
                    $displayValue = if ($customValue.Length -gt 100) { 
                        "$($customValue.Substring(0, 100))..." 
                    }
                    else { 
                        $customValue 
                    }
                    Write-Host "    $key`: '$displayValue'" -ForegroundColor Gray
                }
            }
        }
    }
    
    # Raw vCard analysis for Aneta
    Write-Host "`n📄 RAW vCard DATA for Aneta:" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    $vCardContent = Get-Content $vCardFile -Raw
    $vCardBlocks = @()
    $currentBlock = ""
    $inVCard = $false
    
    foreach ($line in ($vCardContent -split "`n")) {
        $line = $line.Trim()
        
        if ($line -eq "BEGIN:VCARD") {
            $inVCard = $true
            $currentBlock = $line + "`n"
        }
        elseif ($line -eq "END:VCARD" -and $inVCard) {
            $currentBlock += $line + "`n"
            $vCardBlocks += $currentBlock
            $currentBlock = ""
            $inVCard = $false
        }
        elseif ($inVCard) {
            $currentBlock += $line + "`n"
        }
    }
    
    # Find Aneta's raw vCard
    $anetaVCard = $vCardBlocks | Where-Object { $_ -match "Aneta" }
    
    if ($anetaVCard) {
        Write-Host "Raw vCard for Aneta Orlowska:" -ForegroundColor Yellow
        Write-Host "-----------------------------" -ForegroundColor Yellow
        $anetaVCard -split "`n" | ForEach-Object { 
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                Write-Host $_ -ForegroundColor White 
            }
        }
    }
    
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n🏁 All fields analysis completed!" -ForegroundColor Green
