# Cihaz Bilgi Scripti

Bu PowerShell scripti, uzak cihazların IP adresini, kullanıcı adını ve MAC adresini almak için tasarlanmıştır. Cihazın erişilebilirliğini kontrol eder, RPC servisinin çalıştığından emin olur ve ardından gerekli bilgileri toplar.

## Gereksinimler

- **Domain Admin Yetkileri**: Script, uzak cihazlara erişim ve yönetim için gerekli yetkilere sahip olması gerektiğinden, domain admin yetkileriyle çalıştırılmalıdır.
- **PowerShell**: Bilgisayarınızda PowerShell'in kurulu olduğundan emin olun.
- **Uzak Cihazlar**: Hedef cihazlar ağa erişilebilir durumda olmalıdır.

## Kullanım

### Scripti Çalıştırma Adımları

1. **Depoyu Klonlayın**: Bu depoyu yerel bilgisayarınıza klonlayın.
    ```sh
    git clone https://github.com/HilaliAhmer/Get-DeviceInfo.git
    ```

2. **Script Dizinine Geçin**: Dizin değiştirin ve scriptin bulunduğu klasöre gidin.
    ```sh
    cd depo-adi
    ```

3. **PowerShell'i Yönetici Olarak Çalıştırın**: PowerShell'i yönetici olarak açın. PowerShell simgesine sağ tıklayın ve "Yönetici olarak çalıştır" seçeneğine tıklayın.

4. **Execution Policy'yi Ayarlayın**: Script çalıştırma kısıtlamalarını geçici olarak kaldırın.
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    ```

5. **Scripti Çalıştırın**: Scripti, kontrol etmek istediğiniz cihazların IP adresleri ile çalıştırın.
    ```powershell
    .\get-deviceinfo.ps1
    ```

### Örnek Script

İşte `get-deviceinfo.ps1` dosyasına kopyalayıp yapıştırmanız gereken tam script:

```powershell
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
#$ipAddresses = @("10.138.100.5", "10.138.100.69", "10.138.100.100")
$ipAddresses = @("10.138.100.200")

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
