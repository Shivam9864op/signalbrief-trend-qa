param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

Add-Type -AssemblyName System.Drawing
$docs = Join-Path $ProjectRoot 'docs'
New-Item -ItemType Directory -Force -Path $docs | Out-Null
$audit = (node (Join-Path $ProjectRoot 'src/cli.mjs') audit (Join-Path $ProjectRoot 'fixtures/trends.json') --json | ConvertFrom-Json)
$benchmark = (node (Join-Path $ProjectRoot 'src/cli.mjs') benchmark | ConvertFrom-Json)

function Font([string]$name, [float]$size, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) { New-Object System.Drawing.Font($name,$size,$style,[System.Drawing.GraphicsUnit]::Pixel) }
function Brush([string]$hex) { New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($hex)) }
function Box($g,[float]$x,[float]$y,[float]$w,[float]$h,[string]$fill,[string]$stroke='#263956') { $g.FillRectangle((Brush $fill),$x,$y,$w,$h); $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($stroke),2)),$x,$y,$w,$h) }
function Text($g,[string]$value,[float]$x,[float]$y,$font,$brush) { $g.DrawString($value,$font,$brush,$x,$y) }
function New-Canvas([int]$w,[int]$h,[string]$bg) { $bmp=New-Object System.Drawing.Bitmap($w,$h); $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $g.Clear([System.Drawing.ColorTranslator]::FromHtml($bg)); return @($bmp,$g) }
function StatusBrush([string]$status) { if($status -eq 'ready_for_brief'){ return (Brush '#56d69a') }; if($status -eq 'rejected'){ return (Brush '#ff8f8f') }; return (Brush '#f6c85f') }

$title=Font 'Arial' 34 ([System.Drawing.FontStyle]::Bold); $head=Font 'Arial' 23 ([System.Drawing.FontStyle]::Bold); $body=Font 'Arial' 18; $small=Font 'Arial' 14; $mono=Font 'Consolas' 17; $monoBold=Font 'Consolas' 21 ([System.Drawing.FontStyle]::Bold)
$white=Brush '#edf4ff'; $muted=Brush '#91a4be'; $green=Brush '#56d69a'; $amber=Brush '#f6c85f'; $red=Brush '#ff8f8f'; $blue=Brush '#83b8ff'; $line=New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#263956'),2)

# Dashboard screenshot: cards are populated from the real CLI result JSON.
$c=New-Canvas 1600 980 '#0b1220'; $bmp=$c[0]; $g=$c[1]
Text $g 'SignalBrief' 64 44 $title $white; Text $g 'Trend-to-post evidence desk' 66 94 $body $muted; Text $g 'PERSONAL OPEN-SOURCE DEMO · SYNTHETIC DATA · LOCAL RUN' 66 137 $small $green
Text $g 'No platform login · No auto-publish' 1215 62 $small $blue
$counts=$audit.summary
$labels=@(@('Items',$counts.total,'#83b8ff'),@('Ready',$counts.ready_for_brief,'#56d69a'),@('Human review',$counts.needs_review,'#f6c85f'),@('Needs evidence',$counts.needs_evidence,'#f6c85f'),@('Rejected',$counts.rejected,'#ff8f8f'))
for($i=0;$i -lt $labels.Count;$i++){ $x=64+$i*300; Box $g $x 180 270 92 '#121d31'; Text $g ([string]$labels[$i][1]) ($x+18) 197 (Font 'Arial' 30 ([System.Drawing.FontStyle]::Bold)) (Brush $labels[$i][2]); Text $g $labels[$i][0].ToUpper() ($x+18) 242 $small $muted }
Text $g 'TREND QUEUE' 64 318 $head $white; Text $g 'SCORE + FLAGS + TRACE ID' 1330 325 $small $muted
$y=370
foreach($result in $audit.results){
  $fill=if($result.status -eq 'ready_for_brief'){'#102b22'}elseif($result.status -eq 'rejected'){'#2b171d'}else{'#2a2416'}; Box $g 64 $y 1470 72 $fill
  $topic=if($result.normalized.topic){$result.normalized.topic}else{'invalid record (missing topic)'}; Text $g ($topic -replace '^(.{0,53}).*','$1') 86 ($y+14) $body $white; Text $g ($result.status -replace '_',' ') 1040 ($y+16) $small (StatusBrush $result.status); Text $g ('score '+$result.score) 1230 ($y+16) $small $blue; Text $g ('flags '+$result.flags.Count+' · trace '+$result.traceId) 86 ($y+42) $small $muted; $y+=84
}
Text $g 'Selected: trend-001 · generated brief is shown in the detail panel' 64 885 $small $muted; Text $g 'Personal open-source demo · synthetic data · local run · not client work' 64 930 $small $muted
$bmp.Save((Join-Path $docs 'dashboard.png'),[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose();$bmp.Dispose()

# Console audit screenshot: text is taken from the same verified fixture run.
$c=New-Canvas 1600 920 '#101827'; $bmp=$c[0];$g=$c[1]
Text $g '$ npm run audit' 60 42 $mono $blue; Text $g 'SIGNALBRIEF TREND-TO-POST EVIDENCE DESK' 60 92 $monoBold $white; Text $g ('items='+$counts.total+' ready='+(($counts.ready_for_brief)??0)+' review='+(($counts.needs_review)??0)+' evidence='+(($counts.needs_evidence)??0)+' rejected='+(($counts.rejected)??0)+' duplicate='+(($counts.duplicate)??0)) 60 133 $mono $green
$y=194; foreach($result in $audit.results){ Text $g (('{0,-13} {1,-16} score={2,3} flags={3} trace={4}' -f $result.trendId,$result.status,$result.score,$result.flags.Count,$result.traceId)) 60 $y $mono $muted; $y+=34; foreach($reason in @($result.reasons | Select-Object -First 1)){ Text $g ('  - '+$reason) 95 $y $small (StatusBrush $result.status); $y+=31 }; $y+=13 }
Text $g 'boundary=synthetic_data_only local_run=true no_platform_login=true' 60 840 $mono $muted
$bmp.Save((Join-Path $docs 'console-audit.png'),[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()

# Evidence pack screenshot: a human-readable export of one ready and one review result.
$c=New-Canvas 1600 920 '#f4f7fb';$bmp=$c[0];$g=$c[1];$dark=Brush '#173557';$gray=Brush '#5a6b84';$ink=Brush '#263b58'
Text $g 'SignalBrief evidence pack' 70 48 $title $dark; Text $g 'export.json · generated from fixtures/trends.json · local run' 72 96 $body $gray; Box $g 70 150 1460 640 '#ffffff' '#d7e1ee'; Text $g 'REVIEW RECORD' 110 190 $small $gray; $ready=$audit.results | Where-Object {$_.status -eq 'ready_for_brief'} | Select-Object -First 1; Text $g ('trendId: '+$ready.trendId) 110 235 $mono $ink; Text $g ('status: '+$ready.status+'    score: '+$ready.score+'/100') 110 270 $mono $green; Text $g ('traceId: '+$ready.traceId) 110 305 $mono $gray; Text $g 'score breakdown' 110 356 $head $dark; Text $g ('freshness '+$ready.scoreBreakdown.freshness+'  ·  evidence '+$ready.scoreBreakdown.evidence+'  ·  audience '+$ready.scoreBreakdown.audience+'  ·  novelty '+$ready.scoreBreakdown.novelty+'  ·  safety '+$ready.scoreBreakdown.safety) 110 396 $body $ink; Text $g 'generated brief' 110 460 $head $dark; Text $g ($ready.brief.angle) 110 500 $body $ink; Text $g ('hook 1: '+$ready.brief.hooks[0]) 110 536 $body $ink; Text $g ('hook 2: '+$ready.brief.hooks[1]) 110 572 $body $ink; Text $g ('cta: '+$ready.brief.cta) 110 608 $body $ink; Text $g 'reviewer decision: pending · notes: add human approval before publishing' 110 692 $body (Brush '#805a16'); Text $g 'Personal open-source demo · synthetic data · not client work' 110 742 $small $gray
$bmp.Save((Join-Path $docs 'evidence-pack.png'),[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose();$dark.Dispose();$gray.Dispose();$ink.Dispose()

# Architecture panel raster, kept beside the source SVG for social uploads.
$c=New-Canvas 1600 820 '#f4f7fb';$bmp=$c[0];$g=$c[1];$navy=Brush '#173557';$gray=Brush '#5a6b84';$panel=Brush '#ffffff';$stroke2=New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#d7e1ee'),2)
Text $g 'SignalBrief workflow' 70 48 $title $navy;Text $g 'ingest → check → score → brief → human review' 72 96 $body $gray
$steps=@(@('1  INGEST','JSON / CSV / webhook'),@('2  CHECK','freshness · evidence · rights'),@('3  SCORE','0–100 + trace ID'),@('4  HANDOFF','brief or review queue'))
for($i=0;$i -lt $steps.Count;$i++){ $x=70+$i*370; Box $g $x 210 310 190 '#ffffff' '#d7e1ee'; Text $g $steps[$i][0] ($x+22) 250 $head $navy; Text $g $steps[$i][1] ($x+22) 300 $body $gray; if($i -lt 3){Text $g '→' ($x+330) 282 (Font 'Arial' 32 ([System.Drawing.FontStyle]::Bold)) (Brush '#83b8ff')} }
Box $g 250 510 1100 105 '#fff8e9' '#e8c982';Text $g 'Human review queue' 290 548 $head (Brush '#805a16');Text $g 'Fix evidence · confirm rights · approve · export evidence pack' 290 582 $body (Brush '#805a16');Text $g 'Boundary: no platform login · no scraping · no auto-publish' 70 724 $body $gray;Text $g 'Personal open-source demo · synthetic data · local run · not client work' 70 766 $small $gray
$bmp.Save((Join-Path $docs 'architecture.png'),[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose();$navy.Dispose();$gray.Dispose();$panel.Dispose();$stroke2.Dispose()

# Honest benchmark screenshot from the real 10,000-record benchmark command.
$c=New-Canvas 1600 820 '#101827';$bmp=$c[0];$g=$c[1];Text $g '$ npm run benchmark' 60 54 $mono $blue;Text $g 'SIGNALBRIEF LOCAL BENCHMARK' 60 122 $monoBold $white;Text $g ('records='+$benchmark.records+'  elapsedMs='+$benchmark.elapsedMs) 60 188 $mono $green;Text $g 'counts' 60 270 $head $white; $y=325;foreach($prop in $benchmark.counts.psobject.Properties){Text $g ($prop.Name.PadRight(20)+' '+$prop.Value) 80 $y $mono $muted;$y+=39};Text $g 'syntheticData=true · deterministic rules · no network calls' 60 680 $mono $muted;Text $g 'Personal open-source demo · local run · not a throughput promise' 60 735 $small $muted;$bmp.Save((Join-Path $docs 'benchmark-run.png'),[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()

Write-Host "Rendered verified visuals to $docs"
