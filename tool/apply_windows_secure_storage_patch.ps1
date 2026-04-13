# 將 flutter_secure_storage_windows 改為不依賴 ATL（避免未安裝「C++ ATL」時 build 失敗）。
# 在專案根目錄執行：powershell -ExecutionPolicy Bypass -File tool\apply_windows_secure_storage_patch.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    Write-Error "請在專案根目錄下的 tool 資料夾執行此腳本（找不到 pubspec.yaml）。"
}

if ($env:PUB_CACHE) {
    $cacheRoot = $env:PUB_CACHE
} else {
    $cacheRoot = Join-Path $env:LOCALAPPDATA "Pub\Cache"
}
if (-not (Test-Path $cacheRoot)) {
    Write-Error "找不到 pub 快取目錄：$cacheRoot"
}
$src = Join-Path $root "tool\patches\flutter_secure_storage_windows-3.1.2\windows\flutter_secure_storage_windows_plugin.cpp"
$dst = Join-Path $cacheRoot "hosted\pub.dev\flutter_secure_storage_windows-3.1.2\windows\flutter_secure_storage_windows_plugin.cpp"
if (-not (Test-Path $src)) {
    Write-Error "找不到修補檔：$src"
}
if (-not (Test-Path $dst)) {
    Write-Warning "快取中尚無 flutter_secure_storage_windows-3.1.2，請先在此專案執行 flutter pub get。"
    exit 1
}
Copy-Item -LiteralPath $src -Destination $dst -Force
Write-Host "已套用修補至：$dst"
