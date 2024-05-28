# IP adresleri listesi
#$ipAddresses = @("192.168.1.100", "192.168.1.102", "192.168.1.150", "192.168.1.160", "192.168.1.90", "192.168.1.55")
#$ipAddresses = @("192.168.1.100")

# Bu komutu çalıştırabilmek için powershell ISE'yi domain admin yetkisinde çalıştırman gerekir. Sonrasında hangi ip'lerde aramak istiyorsan onları en alt satırda yazman yeterli.

function Format-Table {
    param (
        [array]$data
    )

    $columns = @('IPAddress', 'UserName', 'MACAddress')
    
    # Sütun genişliklerini belirle
    $colWidths = @{}
    foreach ($col in $columns) {
        $maxWidth = ($data | Measure-Object -Property $col -Maximum | Select-Object -ExpandProperty Maximum).Length
        $colWidths[$col] = [Math]::Max($col.Length, $maxWidth)
    }

    # Başlık ve ayraçları yazdır
    $header = $columns | ForEach-Object { $_.PadRight($colWidths[$_]) }
    $divider = '+' + ($columns | ForEach-Object { '-' * ($colWidths[$_] + 2) }) -join '+' + '+'
    
    Write-Host $divider
    Write-Host "| " + ($header -join " | ") + " |"
    Write-Host $divider

    # Her satır için verileri yazdır
    foreach ($item in $data) {
        $row = $columns | ForEach-Object { $item.$_.ToString().PadRight($colWidths[$_]) }
        Write-Host "| " + ($row -join " | ") + " |"
    }
    Write-Host $divider
}

function Test-DeviceAccessibility {
    param (
        [string]$ip
    )
    
    Write-Host "Cihaz $ip adresine ping atılıyor..." -ForegroundColor Yellow
    $ping = Test-Connection -ComputerName $ip -Count 1 -ErrorAction SilentlyContinue
    
    if ($ping.StatusCode -eq 0) {
        Write-Host "Cihaz çevrim içi ve erişilebilir." -ForegroundColor Green
        return $true
    } else {
        Write-Host "Cihaz erişilebilir değil." -ForegroundColor Red
        return $false
    }
}

function Get-DeviceInfo {
    param (
        [string]$ip
    )
    
    if (-not (Test-DeviceAccessibility -ip $ip)) {
        return
    }

    Write-Host "RPC servisi durumu kontrol ediliyor..." -ForegroundColor Yellow
    $rpcService = Get-Service -ComputerName $ip -Name RpcSs -ErrorAction SilentlyContinue
    $initialRpcState = $rpcService.Status

    if ($initialRpcState -eq "Running") {
        Write-Host "RPC servisi çalışıyor." -ForegroundColor Green
    } else {
        Write-Host "RPC servisi çalışmıyor, aktif ediliyor..." -ForegroundColor Red
        Invoke-Command -ComputerName $ip -ScriptBlock { Start-Service -Name RpcSs } -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 15  # Bekleme süresini artırın
        Write-Host "RPC servisi aktif edildi." -ForegroundColor Green
    }

    Write-Host "Kullanıcı ve MAC adresi bilgileri alınıyor..." -ForegroundColor Yellow
    try {
        $wmi = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ip -ErrorAction Stop
        $network = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ip -Filter "IPEnabled = True" -ErrorAction Stop
    } catch {
        Write-Host "RPC sunucusu hala kullanılamıyor." -ForegroundColor Red
        return
    }

    $macAddress = $network.MACAddress
    $userName = $wmi.UserName

    $results = [PSCustomObject]@{
        IPAddress  = $ip
        UserName   = $userName
        MACAddress = $macAddress
    }

    Write-Host "Bilgiler başarıyla alındı." -ForegroundColor Green
    return $results
}

cls

# IP adresleri listesi
$ipAddresses = @("192.168.1.100", "192.168.1.102", "192.168.1.150", "192.168.1.160", "192.168.1.90", "192.168.1.55")
#$ipAddresses = @("192.168.1.100")

# Tüm sonuçları topla
$allResults = @()
foreach ($ip in $ipAddresses) {
    $result = Get-DeviceInfo -ip $ip
    if ($result) {
        $allResults += $result
    }
}

# Sonuçları tablo olarak yazdır
if ($allResults.Count -gt 0) {
    Format-Table -data $allResults
}
