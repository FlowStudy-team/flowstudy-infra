#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$CoreBaseUrl = 'http://127.0.0.1:8080',
    [string]$JMeterPath = 'F:\software\apache-jmeter-5.6.3\bin\jmeter.bat',
    [string]$MySqlPath = 'D:\software\MySQL\mysql-5.7.24-winx64\bin\mysql.exe',
    [string]$RedisCliPath = 'F:\software\Redis-x64-3.2.100\redis-cli.exe',
    [string]$DbPassword = $env:FLOWSTUDY_PERF_DB_PASSWORD,
    [string]$RabbitPassword = $env:FLOWSTUDY_PERF_RABBIT_PASSWORD,
    [string]$ConcurrencyCsv = '50,100,200',
    [int]$Stock = 100,
    [int]$RampSeconds = 1,
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
$dbHost = '127.0.0.1'
$dbName = 'flowstudy'
$dbUser = 'flowstudy'
$rabbitUser = 'flowstudy'
$root = $PSScriptRoot
$runId = Get-Date -Format 'yyyyMMddHHmmss'
$out = Join-Path (Join-Path $root 'results') $runId
$testPassword = 'FlowStudyPerf_2026!'
$concurrencyLevels = @(
    $ConcurrencyCsv -split ',' | ForEach-Object {
        $value = $_.Trim()
        if ($value -notmatch '^\d+$' -or [int]$value -lt 1 -or [int]$value -gt 1000) {
            throw "Invalid concurrency value: '$value'. Use comma-separated integers from 1 to 1000."
        }
        [int]$value
    }
)

foreach ($path in @($JMeterPath, $MySqlPath, $RedisCliPath, (Join-Path $root 'seckill.jmx'))) {
    if (-not (Test-Path $path)) { throw "Missing required file: $path" }
}
if ([string]::IsNullOrWhiteSpace($DbPassword)) { throw 'Set FLOWSTUDY_PERF_DB_PASSWORD or pass -DbPassword.' }
if ([string]::IsNullOrWhiteSpace($RabbitPassword)) { $RabbitPassword = $DbPassword }
New-Item -ItemType Directory -Force $out | Out-Null

function Invoke-MySql([string]$sql) {
    $oldPassword = $env:MYSQL_PWD
    try {
        $env:MYSQL_PWD = $DbPassword
        $result = & $MySqlPath '--protocol=tcp' "--host=$dbHost" "--user=$dbUser" "--database=$dbName" '--batch' '--skip-column-names' '--raw' '--execute' $sql 2>&1
        if ($LASTEXITCODE -ne 0) { throw "MySQL failed: $($result -join ' ')" }
        return ($result -join "`n").Trim()
    } finally { $env:MYSQL_PWD = $oldPassword }
}

function Invoke-Redis([string[]]$commandArgs) {
    $result = & $RedisCliPath -h $dbHost -p 6379 @commandArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Redis failed: $($result -join ' ')" }
    return ($result -join "`n").Trim()
}

function Get-Percentile([double[]]$values, [double]$percentile) {
    if ($values.Count -eq 0) { return 0 }
    $sorted = @($values | Sort-Object)
    $index = [Math]::Max(0, [Math]::Ceiling($sorted.Count * $percentile) - 1)
    return [Math]::Round([double]$sorted[$index], 2)
}

function Get-StoreQueueDepth {
    try {
        $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$rabbitUser`:$RabbitPassword"))
        $queue = Invoke-RestMethod -Uri 'http://127.0.0.1:15672/api/queues/%2F/flowstudy.store.order.queue' -Headers @{ Authorization = "Basic $basic" } -TimeoutSec 5
        return [int]$queue.messages
    } catch { return $null }
}

function Wait-ForOrders([long]$productId, [int]$expected) {
    $previous = -1
    $stable = 0
    for ($i = 0; $i -lt 60; $i++) {
        $count = [int](Invoke-MySql "SELECT COUNT(*) FROM fs_membership_order WHERE product_id=$productId")
        $depth = Get-StoreQueueDepth
        if ($count -eq $previous -and ($null -eq $depth -or $depth -eq 0)) { $stable++ } else { $stable = 0 }
        if ($count -ge $expected -and $stable -ge 2) { return @{ Count = $count; Depth = $depth; Settled = $true } }
        $previous = $count
        Start-Sleep -Seconds 1
    }
    return @{ Count = [int](Invoke-MySql "SELECT COUNT(*) FROM fs_membership_order WHERE product_id=$productId"); Depth = (Get-StoreQueueDepth); Settled = $false }
}

try {
    $health = Invoke-RestMethod -Uri "$CoreBaseUrl/api/health" -TimeoutSec 5
    if ($health.code -ne 0 -or $health.data.status -ne 'UP') { throw 'Core health check failed.' }

    $username = "perf_seckill_$runId"
    $register = @{ username = $username; email = "$username@flowstudy.local"; password = $testPassword; nickname = 'Performance Test' } | ConvertTo-Json -Compress
    $registration = Invoke-RestMethod -Method Post -Uri "$CoreBaseUrl/api/v1/auth/register" -ContentType 'application/json' -Body $register -TimeoutSec 15
    if ($registration.code -ne 0) { throw "Registration failed: $($registration.message)" }
    $login = @{ account = $username; password = $testPassword } | ConvertTo-Json -Compress
    $auth = Invoke-RestMethod -Method Post -Uri "$CoreBaseUrl/api/v1/auth/login" -ContentType 'application/json' -Body $login -TimeoutSec 15
    if ($auth.code -ne 0) { throw "Login failed: $($auth.message)" }
    $token = $auth.data.accessToken
    $summary = @()

    foreach ($threads in $concurrencyLevels) {
        $productName = "PERF_SECKILL_${runId}_${threads}"
        $productId = [int64](Invoke-MySql "INSERT INTO fs_membership_product(name,description,price_cents,token_amount,stock,sold_count,sale_start_at,sale_end_at,status,sort_order) VALUES('$productName','Isolated local load test product',990,1000,$Stock,0,NOW()-INTERVAL 1 MINUTE,DATE_ADD(NOW(),INTERVAL 1 DAY),'ACTIVE',999); SELECT LAST_INSERT_ID();")
        $stockKey = "flowstudy:seckill:product:stock:$productId"
        Invoke-Redis @('DEL', $stockKey) | Out-Null
        $before = Invoke-MySql "SELECT CONCAT(stock,',',sold_count) FROM fs_membership_product WHERE id=$productId"
        Set-Content (Join-Path $out "mysql-before-$threads.txt") "product_id=$productId`nstock,sold_count=$before" -Encoding UTF8

        $coreUri = [Uri]$CoreBaseUrl
        $corePort = if ($coreUri.IsDefaultPort) { if ($coreUri.Scheme -eq 'https') { 443 } else { 80 } } else { $coreUri.Port }
        $scenarioPlan = Join-Path $out "seckill-$threads.jmx"
        $template = Get-Content -Raw (Join-Path $root 'seckill.jmx')
        $template = $template.Replace('${__P(core_host,127.0.0.1)}', $coreUri.Host)
        $template = $template.Replace('${__P(core_port,8080)}', [string]$corePort)
        $template = $template.Replace('${__P(auth_token,)}', $token)
        $template = $template.Replace('${__P(product_id,0)}', [string]$productId)
        $template = $template.Replace('${__P(perf_threads,50)}', [string]$threads)
        $template = $template.Replace('${__P(perf_ramp_seconds,5)}', [string]$RampSeconds)
        $template = $template.Replace('${__P(perf_loops,1)}', '1')
        Set-Content -Path $scenarioPlan -Value $template -Encoding UTF8

        $jtl = Join-Path $out "seckill-$threads.jtl"
        & $JMeterPath -n -t $scenarioPlan -l $jtl '-Jjmeter.save.saveservice.output_format=csv' '-Jjmeter.save.saveservice.print_field_names=true' '-Jjmeter.save.saveservice.response_code=true' '-Jjmeter.save.saveservice.successful=true' '-Jjmeter.save.saveservice.latency=true' '-Jjmeter.save.saveservice.connect_time=true'
        if ($LASTEXITCODE -ne 0) { throw "JMeter failed at concurrency $threads." }

        $rows = @(Import-Csv $jtl)
        if ($rows.Count -eq 0) { throw "No JMeter samples at concurrency $threads." }
        $accepted = @($rows | Where-Object { $_.responseCode -eq '200' }).Count
        $soldOut = @($rows | Where-Object { $_.responseCode -eq '409' }).Count
        $limited = @($rows | Where-Object { $_.responseCode -eq '429' }).Count
        $serverErrors = @($rows | Where-Object { $_.responseCode -match '^5' }).Count
        $latencies = @($rows | ForEach-Object { [double]$_.elapsed })
        $minTs = [double](($rows | Measure-Object timeStamp -Minimum).Minimum)
        $maxEndTs = [double](($rows | ForEach-Object { [double]$_.timeStamp + [double]$_.elapsed } | Measure-Object -Maximum).Maximum)
        $seconds = [Math]::Max(0.001, ($maxEndTs - $minTs) / 1000)
        $settlement = Wait-ForOrders $productId $accepted
        $after = Invoke-MySql "SELECT CONCAT(stock,',',sold_count) FROM fs_membership_product WHERE id=$productId"
        $dbOrders = [int](Invoke-MySql "SELECT COUNT(*) FROM fs_membership_order WHERE product_id=$productId")
        $duplicates = [int](Invoke-MySql "SELECT COUNT(*)-COUNT(DISTINCT order_no) FROM fs_membership_order WHERE product_id=$productId")
        $redisStock = Invoke-Redis @('GET', $stockKey)
        if ([string]::IsNullOrWhiteSpace($redisStock)) { $redisStock = 'MISSING' }
        $depth = Get-StoreQueueDepth
        Set-Content (Join-Path $out "mysql-after-$threads.txt") "product_id=$productId`nstock,sold_count=$after`norders=$dbOrders`nduplicate_order_no=$duplicates" -Encoding UTF8
        Set-Content (Join-Path $out "redis-after-$threads.txt") "key=$stockKey`nstock=$redisStock" -Encoding UTF8
        Set-Content (Join-Path $out "rabbitmq-$threads.txt") "queue=flowstudy.store.order.queue`ndepth=$depth`nsettled=$($settlement.Settled)" -Encoding UTF8

        $dbStock = [int]($after.Split(',')[0])
        $consistent = $dbOrders -le $Stock -and $dbStock -ge 0 -and $duplicates -eq 0 -and ($dbStock + $dbOrders -eq $Stock) -and $redisStock -ne 'MISSING' -and ([int]$redisStock -eq $dbStock)
        $summary += [PSCustomObject]@{
            Concurrency = $threads; ProductId = $productId; InitialStock = $Stock; Requests = $rows.Count
            Http200 = $accepted; Http409SoldOut = $soldOut; Http429RateLimited = $limited; Http5xx = $serverErrors
            Qps = [Math]::Round($rows.Count / $seconds, 2); AvgMs = [Math]::Round(($latencies | Measure-Object -Average).Average, 2)
            P95Ms = Get-Percentile $latencies 0.95; P99Ms = Get-Percentile $latencies 0.99
            DbOrders = $dbOrders; DbStock = $dbStock; RedisStock = $redisStock
            QueueDepth = if ($null -eq $depth) { 'UNAVAILABLE' } else { $depth }
            Settled = $settlement.Settled; Oversell = if ($consistent) { 'NO' } else { 'YES_OR_INCONSISTENT' }
        }
    }

    $summary | Export-Csv (Join-Path $out 'summary.csv') -NoTypeInformation -Encoding UTF8
    $lines = @('# FlowStudy Seckill Local Load Test', '', "- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", '- Core branch: feat/store-seckill', "- Core URL: $CoreBaseUrl", "- Initial stock per scenario: $Stock", '- Each virtual user sends one POST /api/v1/store/orders request.', '', '| Concurrency | Requests | 200 | 409 | 429 | 5xx | QPS | Avg ms | P95 ms | P99 ms | DB orders | DB stock | Redis stock | Queue depth | Oversell |', '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|')
    foreach ($item in $summary) { $lines += ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} | {14} |' -f $item.Concurrency,$item.Requests,$item.Http200,$item.Http409SoldOut,$item.Http429RateLimited,$item.Http5xx,$item.Qps,$item.AvgMs,$item.P95Ms,$item.P99Ms,$item.DbOrders,$item.DbStock,$item.RedisStock,$item.QueueDepth,$item.Oversell) }
    $lines += @('', '## Interpretation', '', '- HTTP 200 means Redis reserved stock and Core published an async order task. MySQL order count is the final business result.', '- 409 is an expected sold-out response for stock-constrained scenarios.', '- No oversell requires DB orders <= initial stock, non-negative DB stock, no duplicate order number, DB stock + DB orders = initial stock, and Redis stock = DB stock.', '- This is a same-host Windows integration test. Do not treat the QPS or latency as ECS production capacity.')
    $report = Join-Path $out 'report.md'
    Set-Content $report $lines -Encoding UTF8
    Write-Host "Load test completed. Report: $report"

    if ($Cleanup) {
        foreach ($item in $summary) {
            Invoke-Redis @('DEL', "flowstudy:seckill:product:stock:$($item.ProductId)") | Out-Null
            Invoke-MySql "DELETE FROM fs_membership_order WHERE product_id=$($item.ProductId); DELETE FROM fs_membership_product WHERE id=$($item.ProductId);" | Out-Null
        }
        Invoke-MySql "DELETE FROM sys_user WHERE username='$username'" | Out-Null
    }
} finally { $env:MYSQL_PWD = $null }
