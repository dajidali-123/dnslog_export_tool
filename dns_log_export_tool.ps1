# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
    exit
}

Write-Host "DNS Client Log Export Tool" -ForegroundColor Cyan
Write-Host ""

# 开启DNS日志
Write-Host "Enabling DNS logging..." -ForegroundColor Yellow
wevtutil sl "Microsoft-Windows-DNS-Client/Operational" /e:true | Out-Null
wevtutil sl "Microsoft-Windows-DNS-Client/Operational" /ms:10485760 | Out-Null

# 生成测试查询
Write-Host "Generating test queries..." -ForegroundColor Yellow
Test-Connection www.huawei.com -Count 1 -Quiet | Out-Null
Test-Connection www.baidu.com -Count 1 -Quiet | Out-Null
Start-Sleep -Seconds 1

# 输出到CSV
$csvPath = "$env:USERPROFILE\Desktop\DNS_Logs_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$events = Get-WinEvent -LogName "Microsoft-Windows-DNS-Client/Operational" -ErrorAction SilentlyContinue

if ($events) {
    $events | ForEach-Object {
        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            EventID = $_.Id
            Level = $_.LevelDisplayName
            ProcessID = $_.Properties[0].Value
            QueryName = $_.Properties[1].Value
            QueryType = $_.Properties[2].Value
            QueryStatus = $_.Properties[4].Value
            QueryResults = if ($_.Properties[5].Value) { $_.Properties[5].Value -replace '[\[\]]', '' } else { '' }
            Message = $_.Message
        }
    } | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Exported $($events.Count) records to:" -ForegroundColor Green
    Write-Host $csvPath -ForegroundColor Cyan
}
else {
    Write-Host "No DNS log records found" -ForegroundColor Yellow
}

Write-Host "Press any key to exit..." -ForegroundColor Gray

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
