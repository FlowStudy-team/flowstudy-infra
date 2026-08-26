param(
    [int]$DocumentCount = 1000000,
    [string]$EsUrl = "http://localhost:9200",
    [string]$Index = "flowstudy-pagination-benchmark",
    [switch]$SkipPrepare,
    [switch]$KeepContainer
)

$ErrorActionPreference = "Stop"
$BenchmarkRoot = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $BenchmarkRoot "docker-compose.yml"
$Generator = Join-Path $PSScriptRoot "generate_data.py"
$Benchmark = Join-Path $PSScriptRoot "benchmark.py"
$Output = Join-Path $BenchmarkRoot "results\es-pagination-summary.csv"

function Invoke-Es([string]$Path) {
    return Invoke-RestMethod -Uri ($EsUrl.TrimEnd("/") + $Path) -Method Get
}

if (-not $SkipPrepare) {
    docker compose -f $ComposeFile up -d
    $ready = $false
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        try {
            $health = Invoke-Es "/_cluster/health"
            if ($health.status -in @("yellow", "green")) { $ready = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { throw "Elasticsearch did not become ready within 120 seconds." }

    python $Generator --es-url $EsUrl --index $Index --count $DocumentCount --recreate
}

python $Benchmark --es-url $EsUrl --index $Index --output $Output

if (-not $KeepContainer -and -not $SkipPrepare) {
    docker compose -f $ComposeFile down
}
