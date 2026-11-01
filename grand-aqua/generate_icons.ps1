Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\lenovo\.gemini\antigravity\brain\96736d5c-977a-4fd0-9ef9-86cd753d248e\.user_uploaded\media_1793336625610_08a2ab10.png"
$fullImg = [System.Drawing.Bitmap]::FromFile($srcPath)

# Content bounds: minX=38, minY=52, width=716, height=204
$cropRect = New-Object System.Drawing.Rectangle(38, 52, 716, 204)
$logoImg = $fullImg.Clone($cropRect, $fullImg.PixelFormat)
Write-Output "Cropped logo size: $($logoImg.Width) x $($logoImg.Height)"

$densities = @(
    @{ Name = 'mipmap-mdpi';    LegacySize = 48;  FgSize = 108 },
    @{ Name = 'mipmap-hdpi';    LegacySize = 72;  FgSize = 162 },
    @{ Name = 'mipmap-xhdpi';   LegacySize = 96;  FgSize = 216 },
    @{ Name = 'mipmap-xxhdpi';  LegacySize = 144; FgSize = 324 },
    @{ Name = 'mipmap-xxxhdpi'; LegacySize = 192; FgSize = 432 }
)

$apps = @(
    "d:\grand_aqua_full\grand-aqua\grand aqua buyer android app\android\app\src\main\res",
    "d:\grand_aqua_full\grand-aqua\grand aqua super admin android app\android\app\src\main\res",
    "d:\grand_aqua_full\grand-aqua\grand aqua salesman android app\android\app\src\main\res"
)

# 1. Background vector XML
$bgXml = '<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M0,0h108v108h-108z" />
</vector>'

# 2. Adaptive Icon XML
$adaptiveXml = '<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>'

function Make-LegacySquare([int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::White)

    $drawW = [int]($size * 0.90)
    $drawH = [int]($drawW * ($logoImg.Height / $logoImg.Width))
    $drawX = [int](($size - $drawW) / 2)
    $drawY = [int](($size - $drawH) / 2)

    $destRect = New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)
    $g.DrawImage($logoImg, $destRect, 0, 0, $logoImg.Width, $logoImg.Height, [System.Drawing.GraphicsUnit]::Pixel)

    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Make-LegacyRound([int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillEllipse($brush, 0, 0, $size, $size)
    $brush.Dispose()

    $drawW = [int]($size * 0.82)
    $drawH = [int]($drawW * ($logoImg.Height / $logoImg.Width))
    $drawX = [int](($size - $drawW) / 2)
    $drawY = [int](($size - $drawH) / 2)

    $destRect = New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)
    $g.DrawImage($logoImg, $destRect, 0, 0, $logoImg.Width, $logoImg.Height, [System.Drawing.GraphicsUnit]::Pixel)

    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Make-AdaptiveForeground([int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # 66% of 108dp canvas = 71.3dp, perfectly inside 72dp safe zone circle (66.7%)
    # For 432px, drawW = 285px, drawH = 81px
    $drawW = [int]($size * 0.66)
    $drawH = [int]($drawW * ($logoImg.Height / $logoImg.Width))
    $drawX = [int](($size - $drawW) / 2)
    $drawY = [int](($size - $drawH) / 2)

    $destRect = New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)
    $g.DrawImage($logoImg, $destRect, 0, 0, $logoImg.Width, $logoImg.Height, [System.Drawing.GraphicsUnit]::Pixel)

    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

foreach ($resDir in $apps) {
    Write-Output "Processing $resDir..."

    # Ensure drawable dir
    $drawDir = Join-Path $resDir "drawable"
    if (-not (Test-Path $drawDir)) { New-Item -ItemType Directory -Path $drawDir -Force | Out-Null }
    Set-Content -Path (Join-Path $drawDir "ic_launcher_background.xml") -Value $bgXml -Encoding UTF8

    # Ensure mipmap-anydpi-v26 dir
    $v26Dir = Join-Path $resDir "mipmap-anydpi-v26"
    if (-not (Test-Path $v26Dir)) { New-Item -ItemType Directory -Path $v26Dir -Force | Out-Null }
    Set-Content -Path (Join-Path $v26Dir "ic_launcher.xml") -Value $adaptiveXml -Encoding UTF8
    Set-Content -Path (Join-Path $v26Dir "ic_launcher_round.xml") -Value $adaptiveXml -Encoding UTF8

    foreach ($d in $densities) {
        $targetDir = Join-Path $resDir $d.Name
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

        Make-LegacySquare $d.LegacySize (Join-Path $targetDir "ic_launcher.png")
        Make-LegacyRound $d.LegacySize (Join-Path $targetDir "ic_launcher_round.png")
        Make-AdaptiveForeground $d.FgSize (Join-Path $targetDir "ic_launcher_foreground.png")
    }
}

$logoImg.Dispose()
$fullImg.Dispose()
Write-Output "All icons successfully generated!"
