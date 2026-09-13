param(
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\remote-job-card.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Common -ErrorAction SilentlyContinue

$resolved = [System.IO.Path]::GetFullPath($OutputPath)
$parent = Split-Path -Parent $resolved
New-Item -ItemType Directory -Force -Path $parent | Out-Null

$width = 1600
$height = 900
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$navy = [System.Drawing.Color]::FromArgb(11, 18, 32)
$panel = [System.Drawing.Color]::FromArgb(20, 31, 52)
$panel2 = [System.Drawing.Color]::FromArgb(25, 42, 67)
$white = [System.Drawing.Color]::FromArgb(244, 248, 252)
$muted = [System.Drawing.Color]::FromArgb(178, 194, 212)
$green = [System.Drawing.Color]::FromArgb(55, 211, 153)
$blue = [System.Drawing.Color]::FromArgb(91, 166, 255)
$orange = [System.Drawing.Color]::FromArgb(255, 184, 92)

$graphics.Clear($navy)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.Point(0, 0)),
  (New-Object System.Drawing.Point($width, $height)),
  [System.Drawing.Color]::FromArgb(11, 18, 32),
  [System.Drawing.Color]::FromArgb(18, 41, 62)
)
$graphics.FillRectangle($bgBrush, 0, 0, $width, $height)
$bgBrush.Dispose()

function Font([float]$size, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
  New-Object System.Drawing.Font('Segoe UI', $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}
function Brush($color) { New-Object System.Drawing.SolidBrush($color) }
function DrawText($text, $font, $color, [float]$x, [float]$y, [float]$maxWidth = 1400) {
  $brush = Brush $color
  $rect = New-Object System.Drawing.RectangleF($x, $y, $maxWidth, 200)
  $graphics.DrawString($text, $font, $brush, $rect)
  $brush.Dispose()
}
function RoundPanel([float]$x, [float]$y, [float]$w, [float]$h, $color) {
  $brush = Brush $color
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $r = 18
  $path.AddArc($x, $y, $r, $r, 180, 90)
  $path.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
  $path.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
  $path.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
  $path.CloseFigure()
  $graphics.FillPath($brush, $path)
  $path.Dispose()
  $brush.Dispose()
}

DrawText 'OPEN TO REMOTE WORK' (Font 24 ([System.Drawing.FontStyle]::Bold)) $green 72 48 600
DrawText 'Workflow QA & Automation' (Font 54 ([System.Drawing.FontStyle]::Bold)) $white 72 88 1000
DrawText 'JavaScript / Node.js  ·  REST APIs  ·  Webhooks' (Font 25) $muted 76 160 1000

RoundPanel 72 230 690 438 $panel
DrawText 'What I can help with' (Font 27 ([System.Drawing.FontStyle]::Bold)) $white 104 264 600
$items = @(
  'Reproduce workflow failures and edge cases',
  'Test validation, duplicates and idempotency',
  'Verify retries, error logs and safe handoffs',
  'Write clear expected-vs-actual QA reports'
)
$iy = 320
foreach ($item in $items) {
  $dot = Brush $green
  $graphics.FillEllipse($dot, 108, $iy + 9, 12, 12)
  $dot.Dispose()
  DrawText $item (Font 23) $white 138 $iy 590
  $iy += 58
}
DrawText 'Also comfortable reviewing Hindi/English outputs.' (Font 19) $muted 108 568 600

RoundPanel 800 230 728 438 $panel2
DrawText 'Available now' (Font 27 ([System.Drawing.FontStyle]::Bold)) $white 832 264 640
DrawText 'Remote  ·  10–20 hours/week' (Font 25 ([System.Drawing.FontStyle]::Bold)) $green 832 320 640
DrawText 'Hourly contract or a small paid trial' (Font 23) $white 832 365 640
DrawText 'Personal open-source proof' (Font 21 ([System.Drawing.FontStyle]::Bold)) $orange 832 430 640
DrawText 'SignalBrief  ·  Event Reliability Lab' (Font 21) $white 832 470 640
DrawText 'LeadOps  ·  Contract Drift Monitor' (Font 21) $white 832 505 640
DrawText 'Synthetic data only  ·  not paid client work' (Font 18) $muted 832 555 640
DrawText 'github.com/Shivam9864op/signalbrief-trend-qa' (Font 18 ([System.Drawing.FontStyle]::Bold)) $blue 832 600 650

$line = New-Object System.Drawing.Pen($green, 3)
$graphics.DrawLine($line, 72, 725, 1528, 725)
$line.Dispose()
DrawText 'Hiring managers: I am ready for practical remote work in workflow QA, API integrations, automation testing or AI evaluation.' (Font 22) $white 72 755 1456
DrawText 'Personal portfolio visual  ·  local project evidence  ·  no guaranteed results' (Font 16) $muted 72 824 1456

$bitmap.Save($resolved, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
Write-Output "Wrote $resolved"
