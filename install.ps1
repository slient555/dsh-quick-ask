# 把 overlay/ 装到本机，并建好快捷方式
# 用法：右键 → 使用 PowerShell 运行

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root 'overlay'
$dst = Join-Path $env:LOCALAPPDATA 'dsh-quick-ask\app'

Write-Host '== dsh-quick-ask 安装 ==' -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $src 'QuickAsk.ps1'))) {
    throw "找不到 overlay\QuickAsk.ps1，确认脚本和 overlay 在同一目录"
}

# 1. 复制程序
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
Copy-Item (Join-Path $src '*') $dst -Recurse -Force
Write-Host "已复制到 $dst"

# 2. 快捷方式（桌面 + 启动）
$ws = New-Object -ComObject WScript.Shell
$vbs = Join-Path $dst 'Start-QuickAsk.vbs'

$desktop = [Environment]::GetFolderPath('Desktop')
$lnk = $ws.CreateShortcut((Join-Path $desktop 'DSH 快速问答.lnk'))
$lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
$lnk.Arguments = "`"$vbs`""
$lnk.WorkingDirectory = $dst
$lnk.IconLocation = "$env:WINDIR\System32\shell32.dll,21"
$lnk.Description = 'DSH 快速问答：Ctrl+Alt+A 截图识题'
$lnk.Save()
Write-Host '已创建桌面快捷方式'

$startup = [Environment]::GetFolderPath('Startup')
$lnk2 = $ws.CreateShortcut((Join-Path $startup 'DSH 快速问答.lnk'))
$lnk2.TargetPath = "$env:WINDIR\System32\wscript.exe"
$lnk2.Arguments = "`"$vbs`""
$lnk2.WorkingDirectory = $dst
$lnk2.Save()
Write-Host '已加入开机启动（不想要就删 %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\DSH 快速问答.lnk）'

# 3. 自检
Write-Host ''
Write-Host '== 自检 ==' -ForegroundColor Cyan
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dst 'QuickAsk.ps1') -SelfTest

Write-Host ''
Write-Host '装好了。按 Ctrl+Alt+A 试试；没反应就跑 QuickAsk-Console.cmd 看报错。' -ForegroundColor Green
