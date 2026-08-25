$ErrorActionPreference = 'Stop'

$dataPath = Join-Path $PSScriptRoot 'dialog_dashboard_data_notion.json'
$dashboardPath = Join-Path $PSScriptRoot 'dialog_dashboard_final.html'
$tempPath = Join-Path $PSScriptRoot 'dialog_dashboard_final.next.html'

$data = Get-Content -LiteralPath $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$events = @($data.project.events)
if ($events.Count -ne 39) { throw "ООО Диалог: ожидалось 39 мероприятий, получено $($events.Count)" }
if (@($events | Group-Object '№' | Where-Object Count -ne 1).Count -gt 0) { throw 'ООО Диалог: обнаружены повторяющиеся номера мероприятий.' }
$allowedStatuses = @('Выполнено','В работе','План')
if (@($events | Where-Object { $_.'Статус' -notin $allowedStatuses }).Count -gt 0) { throw 'ООО Диалог: обнаружен неподдерживаемый статус.' }

$notion = foreach ($e in $events) {
    [ordered]@{
        n = [int]$e.'№'
        name = [string]$e.'Мероприятие'
        status = [string]$e.'Статус'
        block = [string]$e.'Блок'
        cc = ([string]$e.'На критической цепи' -eq 'Да')
        dur = if ($null -eq $e.'Длительность (дн)') { 0 } else { [double]$e.'Длительность (дн)' }
        t = [string]$e.'Тип задачи CCPM'
        fend = [string]$e.fact_end
        url = [string]$e.url
    }
}

$html = Get-Content -LiteralPath $dashboardPath -Raw -Encoding UTF8
$json = $notion | ConvertTo-Json -Compress -Depth 6
$updated = [regex]::Replace($html, 'const notionFull = \[.*?\];', "const notionFull = $json;", [Text.RegularExpressions.RegexOptions]::Singleline)
if ($updated -eq $html) { throw 'Не удалось заменить массив notionFull в дашборде ООО Диалог.' }
if ($updated -notmatch 'const notionFull = \[') { throw 'Проверка итогового HTML не пройдена.' }

[System.IO.File]::WriteAllText($tempPath, $updated, [System.Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $tempPath -Destination $dashboardPath -Force
Write-Output "ООО Диалог обновлён: $($events.Count) мероприятий"
