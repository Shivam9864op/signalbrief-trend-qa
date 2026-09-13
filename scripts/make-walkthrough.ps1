param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = 'pwsh' }
& $pwsh -NoProfile -File (Join-Path $ProjectRoot 'scripts/render-visuals.ps1') -ProjectRoot $ProjectRoot
$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg -and (Test-Path 'C:\Program Files\BlueStacks_nxt\ffmpeg.exe')) { $ffmpeg = 'C:\Program Files\BlueStacks_nxt\ffmpeg.exe' }
if (-not $ffmpeg) { throw 'ffmpeg is required to create the walkthrough video.' }

$docs = Join-Path $ProjectRoot 'docs'
$frames = @('dashboard','console-audit','evidence-pack','architecture','benchmark-run')
foreach ($name in $frames) {
  Add-Type -AssemblyName System.Drawing
  $bitmap = [System.Drawing.Bitmap]::new((Join-Path $docs "$name.png"))
  $bitmap.Save((Join-Path $docs "$name.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
  $bitmap.Dispose()
}
$filter = '[0:v]scale=1600:980:force_original_aspect_ratio=decrease,pad=1600:980:(ow-iw)/2:(oh-ih)/2,setsar=1[v0];[1:v]scale=1600:980:force_original_aspect_ratio=decrease,pad=1600:980:(ow-iw)/2:(oh-ih)/2,setsar=1[v1];[2:v]scale=1600:980:force_original_aspect_ratio=decrease,pad=1600:980:(ow-iw)/2:(oh-ih)/2,setsar=1[v2];[3:v]scale=1600:980:force_original_aspect_ratio=decrease,pad=1600:980:(ow-iw)/2:(oh-ih)/2,setsar=1[v3];[4:v]scale=1600:980:force_original_aspect_ratio=decrease,pad=1600:980:(ow-iw)/2:(oh-ih)/2,setsar=1[v4];[v0][v1][v2][v3][v4]concat=n=5:v=1:a=0,format=yuv420p[v]'
# Keep each verified local-run frame on screen for ten seconds (50 seconds total).
& $ffmpeg -y -f image2 -loop 1 -framerate 1 -t 10 -i (Join-Path $docs 'dashboard.bmp') -f image2 -loop 1 -framerate 1 -t 10 -i (Join-Path $docs 'console-audit.bmp') -f image2 -loop 1 -framerate 1 -t 10 -i (Join-Path $docs 'evidence-pack.bmp') -f image2 -loop 1 -framerate 1 -t 10 -i (Join-Path $docs 'architecture.bmp') -f image2 -loop 1 -framerate 1 -t 10 -i (Join-Path $docs 'benchmark-run.bmp') -filter_complex $filter -map '[v]' -c:v libopenh264 -r 1 (Join-Path $docs 'walkthrough.mp4')
Write-Host 'Created docs/walkthrough.mp4 (50 seconds, verified local-run frames).'
