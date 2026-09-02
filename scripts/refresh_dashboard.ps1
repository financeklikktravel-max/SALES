<#
Refreshes sales_dashboard.html's embedded transaction/expense data and the
Team Progress section from the KLIKK 2021 Google Sheet, then commits and
pushes if anything changed. Meant to run on a schedule (Windows Task
Scheduler) on a machine with normal internet access - the equivalent cloud
routine can't reach docs.google.com due to that environment's network policy.
#>

$ErrorActionPreference = "Stop"
$ic = [System.Globalization.CultureInfo]::InvariantCulture
$repoPath = "C:\Users\terry\OneDrive\Documents\SALES"
$logPath = Join-Path $repoPath "scripts\refresh.log"
$sheetId = "1f6F6jPGqYya6iA1gPYuNG2H_gMlz56ioii3sp9JS32U"

function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
  Add-Content -Path $logPath -Value $line
  Write-Output $line
}

function ParseMoney($s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return 0 }
  $s = ($s -replace "[₱,\s]", "").Trim()
  if ($s -eq "" -or $s -eq "-" -or $s -eq "NA") { return 0 }
  $neg = $false
  if ($s.StartsWith("(") -and $s.EndsWith(")")) { $neg = $true; $s = $s.Trim("(",")") }
  [double]$v = 0
  if (-not [double]::TryParse($s, [System.Globalization.NumberStyles]::Any, $ic, [ref]$v)) { return 0 }
  if ($neg) { $v = -$v }
  return $v
}

function FmtNum($v) {
  $r = [math]::Round($v, 2)
  return $r.ToString("0.##", $ic)
}

function ParseDateIso($s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $s = $s.Trim()
  if ($s -eq "NA" -or $s -eq "-" -or $s -eq "TBA") { return $null }
  [datetime]$d = Get-Date
  if ([datetime]::TryParse($s, $ic, [System.Globalization.DateTimeStyles]::None, [ref]$d)) {
    return $d.ToString("yyyy-MM-dd")
  }
  return $null
}

function Invoke-Git {
  param([string[]]$GitArgs)
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & git @GitArgs 2>&1 | Out-String
  $ErrorActionPreference = $prevPref
  Log $output.Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function JsStr($s) {
  if ($null -eq $s) { return "null" }
  $s = $s -replace "\\","\\\\" -replace '"','\"' -replace "`r`n"," " -replace "`n"," " -replace "`r"," "
  $s = $s.Trim() -replace "\s+"," "
  return '"' + $s + '"'
}

function FmtCommas($v) {
  $r = [math]::Round($v, 0)
  return $r.ToString("N0", $ic)
}

Log "=== Refresh run started ==="

try {
  Set-Location $repoPath
  Invoke-Git @("pull", "origin", "main")
} catch {
  Log "git pull failed: $_"
  exit 1
}

$work = Join-Path $env:TEMP "klikk_refresh_$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $work | Out-Null

try {
  $txCsv = Join-Path $work "tx.csv"
  $exCsv = Join-Path $work "ex.csv"
  $apCsv = Join-Path $work "ap.csv"

  Invoke-WebRequest -Uri "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=0" -OutFile $txCsv -UseBasicParsing
  Invoke-WebRequest -Uri "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=1349415762" -OutFile $exCsv -UseBasicParsing
  $apOk = $true
  try {
    Invoke-WebRequest -Uri "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=1955501781" -OutFile $apCsv -UseBasicParsing
  } catch {
    Log "AGENT PROGRESS fetch failed, will skip Team Progress update: $_"
    $apOk = $false
  }

  # ---------------- PART A: TRANSACTIONS ----------------
  Add-Type -AssemblyName Microsoft.VisualBasic
  $parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($txCsv)
  $parser.SetDelimiters(",")
  $parser.HasFieldsEnclosedInQuotes = $true
  $null = $parser.ReadFields()

  $rows = New-Object System.Collections.Generic.List[string]
  $minDate = $null; $maxDate = $null; $total = 0; $vspSkipped = 0

  while (-not $parser.EndOfData) {
    $f = $parser.ReadFields()
    $id = if ($f.Length -gt 0) { $f[0].Trim() } else { "" }
    $dateRaw = if ($f.Length -gt 1) { $f[1].Trim() } else { "" }
    $name = if ($f.Length -gt 2) { $f[2].Trim() } else { "" }
    $agent = if ($f.Length -gt 3) { $f[3].Trim() } else { "" }
    $ads = if ($f.Length -gt 4) { $f[4].Trim() } else { "" }
    $pax = if ($f.Length -gt 5) { $f[5].Trim() } else { "" }
    $package = if ($f.Length -gt 9) { $f[9].Trim() } else { "" }
    $destination = if ($f.Length -gt 10) { $f[10].Trim() } else { "" }
    $srp = if ($f.Length -gt 11) { $f[11] } else { "" }
    $totalCost = if ($f.Length -gt 32) { $f[32] } else { "" }
    $cashFlow = if ($f.Length -gt 33) { $f[33] } else { "" }
    $commission = if ($f.Length -gt 34) { $f[34] } else { "" }
    $profit = if ($f.Length -gt 40) { $f[40] } else { "" }
    $status = if ($f.Length -gt 21) { $f[21].Trim() } else { "" }
    $processed = if ($f.Length -gt 22) { $f[22].Trim() } else { "" }

    if ($id -eq "" -or $dateRaw -eq "" -or $name -eq "" -or $status -eq "" -or $name -eq "dummy") { continue }
    if ($ads -eq "VSP") { $vspSkipped++; continue }

    $isoDate = ParseDateIso $dateRaw
    if ($null -eq $isoDate) { continue }
    if ($destination -eq "" -or $destination -eq "NA" -or $destination -eq "-") { $destination = "Unspecified" }

    $total++
    if ($null -eq $minDate -or $isoDate -lt $minDate) { $minDate = $isoDate }
    if ($null -eq $maxDate -or $isoDate -gt $maxDate) { $maxDate = $isoDate }

    [int]$paxInt = 0
    $paxNum = if ([int]::TryParse(($pax -replace "[^\d-]",""), [ref]$paxInt)) { $paxInt } else { 1 }

    $isoProcessed = ParseDateIso $processed
    $processedJs = if ($null -eq $isoProcessed) { "null" } else { JsStr $isoProcessed }

    $row = "[" + (JsStr $isoDate) + "," + (JsStr $name) + "," + (JsStr $agent) + "," + (JsStr $ads) + "," + $paxNum + "," + (JsStr $package) + "," + (JsStr $destination) + "," + (FmtNum (ParseMoney $srp)) + "," + (FmtNum (ParseMoney $totalCost)) + "," + (FmtNum (ParseMoney $cashFlow)) + "," + (FmtNum (ParseMoney $commission)) + "," + (FmtNum (ParseMoney $profit)) + "," + (JsStr $status) + "," + $processedJs + "]"
    $rows.Add($row)
  }
  $parser.Close()

  $txArrayLine = "var TRANSACTIONS_RAW = [" + ($rows -join ",") + "];"
  Log "Transactions parsed: total=$total vspSkipped=$vspSkipped range=$minDate..$maxDate"

  # ---------------- PART A: EXPENSES ----------------
  $parser2 = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($exCsv)
  $parser2.SetDelimiters(",")
  $parser2.HasFieldsEnclosedInQuotes = $true
  $null = $parser2.ReadFields()

  $rows2 = New-Object System.Collections.Generic.List[string]
  $total2 = 0

  while (-not $parser2.EndOfData) {
    $f = $parser2.ReadFields()
    $dateRaw = if ($f.Length -gt 0) { $f[0].Trim() } else { "" }
    $amountRaw = if ($f.Length -gt 1) { $f[1] } else { "" }
    $type = if ($f.Length -gt 2) { $f[2].Trim() } else { "" }
    $branch = if ($f.Length -gt 4) { $f[4].Trim() } else { "" }
    $agent = if ($f.Length -gt 5) { $f[5].Trim() } else { "" }
    $mop = if ($f.Length -gt 6) { $f[6].Trim() } else { "" }

    if ($dateRaw -eq "" -or $amountRaw.Trim() -eq "") { continue }
    $isoDate = ParseDateIso $dateRaw
    if ($null -eq $isoDate) { continue }

    $total2++
    $typeClean = ($type -replace "`r`n"," " -replace "`n"," ").Trim() -replace "\s+"," "
    if ($typeClean -eq "") { $typeClean = "Other" }
    if ($branch -eq "") { $branch = "Unspecified" }
    if ($agent -eq "") { $agent = "Unspecified" }
    if ($mop -eq "") { $mop = "Unspecified" }

    $row = "[" + (JsStr $isoDate) + "," + (FmtNum (ParseMoney $amountRaw)) + "," + (JsStr $typeClean) + "," + (JsStr $branch) + "," + (JsStr $agent) + "," + (JsStr $mop) + "]"
    $rows2.Add($row)
  }
  $parser2.Close()

  $exArrayLine = "var EXPENSES_RAW = [" + ($rows2 -join ",") + "];"
  Log "Expenses parsed: total=$total2"

  # ---------------- SANITY CHECK ----------------
  $htmlPath = Join-Path $repoPath "sales_dashboard.html"
  $prevTxMatch = Select-String -Path $htmlPath -Pattern "5,376 real transactions|(\d[\d,]*) real transactions from" -AllMatches | Select-Object -First 1
  # Fall back: just require a sane minimum and not a collapse.
  if ($total -lt 3000 -or $total2 -lt 3000) {
    Log "SANITY CHECK FAILED: total=$total total2=$total2 look too low. Aborting without committing."
    Remove-Item -Recurse -Force $work
    exit 1
  }

  $lines = Get-Content -LiteralPath $htmlPath -Encoding UTF8
  $snapIdx = ($lines | Select-String -Pattern '^var SNAPSHOT_ISO' | Select-Object -First 1).LineNumber - 1
  $txIdx = ($lines | Select-String -Pattern '^var TRANSACTIONS_RAW' | Select-Object -First 1).LineNumber - 1
  $exIdx = ($lines | Select-String -Pattern '^var EXPENSES_RAW' | Select-Object -First 1).LineNumber - 1

  $today = Get-Date -Format "yyyy-MM-dd"
  $lines[$snapIdx] = "var SNAPSHOT_ISO = `"$today`";"
  $lines[$txIdx] = $txArrayLine
  $lines[$exIdx] = $exArrayLine

  $fullText = [string]::Join("`n", $lines)

  # Update footnote sentences
  $fullText = $fullText -replace '(VSP-channel transactions are excluded from this dashboard by standing request — )\d[\d,]* rows were removed from the [\d,]+ valid transactions in the DAILY TRANSACTIONS tab, leaving [\d,]+\.', "`$1$vspSkipped rows were removed from the $($total + $vspSkipped).ToString('N0') valid transactions in the DAILY TRANSACTIONS tab, leaving $($total.ToString('N0'))."
  $totalFmt = $total.ToString("N0")
  $validFmt = ($total + $vspSkipped).ToString("N0")
  $endDateHuman = [datetime]::ParseExact($maxDate,"yyyy-MM-dd",$ic).ToString("MMM d, yyyy")
  $fullText = $fullText -replace 'VSP-channel transactions are excluded from this dashboard by standing request — \d[\d,]* rows were removed from the [\d,]+ valid transactions in the DAILY TRANSACTIONS tab, leaving [\d,]+\.', "VSP-channel transactions are excluded from this dashboard by standing request — $vspSkipped rows were removed from the $validFmt valid transactions in the DAILY TRANSACTIONS tab, leaving $totalFmt."
  $fullText = $fullText -replace '[\d,]+ real transactions from Jan 1, 2021 to [A-Za-z]+ \d+, \d+, with complete financials', "$totalFmt real transactions from Jan 1, 2021 to $endDateHuman, with complete financials"

  # ---------------- PART B: TEAM PROGRESS ----------------
  if ($apOk) {
    $parser3 = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($apCsv)
    $parser3.SetDelimiters(",")
    $parser3.HasFieldsEnclosedInQuotes = $true
    $null = $parser3.ReadFields()
    $null = $parser3.ReadFields()  # second header row

    $agents = New-Object System.Collections.Generic.List[object]
    while (-not $parser3.EndOfData) {
      $f = $parser3.ReadFields()
      $name = if ($f.Length -gt 0) { $f[0].Trim() } else { "" }
      if ($name -eq "") { continue }
      $status = if ($f.Length -gt 1) { $f[1].Trim() } else { "Regular" }
      $target = ParseMoney ($f[2])
      $actual = ParseMoney ($f[5])
      $pctRaw = if ($f.Length -gt 6) { $f[6].Trim() -replace "%","" } else { "0" }
      [double]$pct = 0
      [double]::TryParse($pctRaw, [System.Globalization.NumberStyles]::Any, $ic, [ref]$pct) | Out-Null
      $remark = if ($f.Length -gt 7) { $f[7].Trim() } else { "" }
      $agents.Add([pscustomobject]@{ Name=$name; Status=$status; Target=$target; Actual=$actual; Pct=$pct; Remark=$remark })
    }
    $parser3.Close()

    if ($agents.Count -ge 3) {
      $sorted = $agents | Sort-Object -Property @{Expression="Pct";Descending=$true}, @{Expression="Actual";Descending=$true}
      $trRows = New-Object System.Collections.Generic.List[string]
      $rank = 0
      foreach ($a in $sorted) {
        $rank++
        $badgeClass = if ($rank -le 3) { "rank-badge top" } else { "rank-badge" }
        $statusClass = if ($a.Status -match "(?i)probationary") { "probationary" } else { "regular" }
        $statusLabel = if ($statusClass -eq "probationary") { "Probationary" } else { "Regular" }
        $color = if ($a.Pct -ge 80) { "--good" } elseif ($a.Pct -ge 60) { "--warning" } else { "--series-6" }
        $remarkHtml = if ([string]::IsNullOrWhiteSpace($a.Remark)) { "—" } else { $a.Remark }
        $pctInt = [math]::Round($a.Pct, 0)
        $tr = "<tr><td><span class=`"$badgeClass`">$rank</span></td><td>$($a.Name)</td><td><span class=`"status-pill $statusClass`">$statusLabel</span></td><td class=`"num`">₱$(FmtCommas $a.Target)</td><td class=`"num`">₱$(FmtCommas $a.Actual)</td><td><div class=`"mini-bar-row`"><div class=`"mini-bar`"><div class=`"mini-bar-fill`" style=`"width:$($pctInt)%;background:var($color);`"></div></div><span class=`"mini-bar-pct`">$($pctInt)%</span></div></td><td class=`"remark-text`">$remarkHtml</td></tr>"
        $trRows.Add($tr)
      }
      $newTbody = ($trRows -join "`n              ")

      $fullText = $fullText -replace '(?s)(<table class="data-table" id="teamProgressTable">.*?<tbody>\s*).*?(\s*</tbody>)', "`${1}$newTbody`${2}"
      $fullText = $fullText -replace '<span class="panel-tag">\d+ AGENTS</span>', "<span class=`"panel-tag`">$($agents.Count) AGENTS</span>"
      $todayHuman = (Get-Date).ToString("MMM d, yyyy")
      $fullText = $fullText -replace 'Pulled [A-Za-z]+ \d+, \d+ — this section is a manual snapshot', "Pulled $todayHuman — this section is a manual snapshot"
      Log "Team Progress updated: $($agents.Count) agents"
    } else {
      Log "AGENT PROGRESS returned only $($agents.Count) rows (<3) - skipping Team Progress update, looks like a fetch problem"
    }
  }

  [System.IO.File]::WriteAllText($htmlPath, $fullText, (New-Object System.Text.UTF8Encoding($true)))

  # ---------------- README ----------------
  $readmePath = Join-Path $repoPath "README.md"
  $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
  $readme = $readme -replace 'Of [\d,]+ valid transactions in the DAILY TRANSACTIONS tab, \d[\d,]* tagged with the VSP channel were removed, leaving \*\*[\d,]+ transactions\*\*', "Of $validFmt valid transactions in the DAILY TRANSACTIONS tab, $vspSkipped tagged with the VSP channel were removed, leaving **$totalFmt transactions**"
  $expenseEndHuman = $endDateHuman
  $readme = $readme -replace '[\d,]+ real transactions from Jan 1, 2021 to [A-Za-z]+ \d+, \d+, each with complete financials \(revenue, cost, commission, profit\), plus [\d,]+ expense records from Dec 29, 2020 to [A-Za-z]+ \d+, \d+', "$totalFmt real transactions from Jan 1, 2021 to $endDateHuman, each with complete financials (revenue, cost, commission, profit), plus $($total2.ToString('N0')) expense records from Dec 29, 2020 to $endDateHuman"
  [System.IO.File]::WriteAllText($readmePath, $readme, (New-Object System.Text.UTF8Encoding($false)))

  # ---------------- COMMIT + PUSH ----------------
  Set-Location $repoPath
  $status = git status --porcelain -- README.md sales_dashboard.html
  if ([string]::IsNullOrWhiteSpace($status)) {
    Log "No changes after refresh - nothing to commit."
  } else {
    Invoke-Git @("add", "README.md", "sales_dashboard.html")
    $commitMsg = "Scheduled refresh: $totalFmt transactions, $($total2.ToString('N0')) expenses through $endDateHuman"
    Invoke-Git @("-c", "user.name=Klikk Travel Finance", "-c", "user.email=finance.klikktravel@gmail.com", "commit", "-m", $commitMsg)
    Invoke-Git @("push", "origin", "main")
    Log "Pushed: $commitMsg"
  }
} catch {
  Log "ERROR: $_"
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Log "=== Refresh run finished ==="
