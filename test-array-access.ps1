#!/usr/bin/env pwsh

Write-Host "🔍 SIMPLE ARRAY ACCESS TEST" -ForegroundColor Yellow

# Test hashtable array access
Write-Host "`n1. Direct hashtable creation:" -ForegroundColor Cyan
$directHash = @{ Address = "test@example.com" }
Write-Host "  Direct hash: $($directHash | ConvertTo-Json -Compress)" -ForegroundColor White
Write-Host "  Address: '$($directHash.Address)'" -ForegroundColor White

Write-Host "`n2. Array with hashtable:" -ForegroundColor Cyan
$array1 = @()
$array1 += @{ Address = "test@example.com" }
Write-Host "  Array count: $($array1.Count)" -ForegroundColor White
Write-Host "  Array: $($array1 | ConvertTo-Json -Compress)" -ForegroundColor White
Write-Host "  First item [0]: $($array1[0] | ConvertTo-Json -Compress)" -ForegroundColor White
Write-Host "  First item Address: '$($array1[0].Address)'" -ForegroundColor White

Write-Host "`n3. PSCustomObject with array property:" -ForegroundColor Cyan
$testObj = [PSCustomObject]@{
    Name           = "Test Person"
    EmailAddresses = @()
}
$testObj.EmailAddresses += @{ Address = "test@example.com" }

Write-Host "  Object: $($testObj | ConvertTo-Json -Compress)" -ForegroundColor White
Write-Host "  EmailAddresses count: $($testObj.EmailAddresses.Count)" -ForegroundColor White
Write-Host "  First email [0]: $($testObj.EmailAddresses[0] | ConvertTo-Json -Compress)" -ForegroundColor White
if ($testObj.EmailAddresses[0]) {
    Write-Host "  First email Address: '$($testObj.EmailAddresses[0].Address)'" -ForegroundColor Green
}
else {
    Write-Host "  First email is NULL!" -ForegroundColor Red
}

Write-Host "`n4. Building via foreach loop:" -ForegroundColor Cyan
$testObj2 = [PSCustomObject]@{
    Name           = "Test Person 2"
    EmailAddresses = @()
}

$validEmails = @()
$validEmails += @{ Address = "test2@example.com" }
$testObj2.EmailAddresses = $validEmails

Write-Host "  Object2: $($testObj2 | ConvertTo-Json -Compress)" -ForegroundColor White
Write-Host "  EmailAddresses count: $($testObj2.EmailAddresses.Count)" -ForegroundColor White
Write-Host "  First email [0]: $($testObj2.EmailAddresses[0] | ConvertTo-Json -Compress)" -ForegroundColor White
if ($testObj2.EmailAddresses[0]) {
    Write-Host "  First email Address: '$($testObj2.EmailAddresses[0].Address)'" -ForegroundColor Green
}
else {
    Write-Host "  First email is NULL!" -ForegroundColor Red
}

Write-Host "`n🏁 Test completed!" -ForegroundColor Green
