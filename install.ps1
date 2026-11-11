# 尚未在真实 Windows 机器上运行过 (has not yet been run on a real Windows machine).
# 把本仓库的 vertical-talking-head-edit 复制到当前用户的 Codex skills 目录。

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    throw '环境变量 USERPROFILE 为空，无法确定用户 skill 目录。'
}

$source = Join-Path $PSScriptRoot '.agents\skills\vertical-talking-head-edit'
$destRoot = Join-Path $env:USERPROFILE '.agents\skills'
$dest = Join-Path $destRoot 'vertical-talking-head-edit'

if (-not (Test-Path -LiteralPath $source)) {
    throw "找不到 skill 源目录：$source"
}

if (-not (Test-Path -LiteralPath $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot | Out-Null
}

if (Test-Path -LiteralPath $dest) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $destRoot "vertical-talking-head-edit.bak-$stamp"
    $n = 0
    while (Test-Path -LiteralPath $backup) {
        $n++
        $backup = Join-Path $destRoot "vertical-talking-head-edit.bak-$stamp-$n"
    }
    Move-Item -LiteralPath $dest -Destination $backup
    Write-Host "已把原有副本备份到：$backup"
}

Copy-Item -LiteralPath $source -Destination $dest -Recurse

Write-Host "已安装到：$dest"
Write-Host "请重启 Codex，然后输入 /skills，确认列表里有 vertical-talking-head-edit。"
