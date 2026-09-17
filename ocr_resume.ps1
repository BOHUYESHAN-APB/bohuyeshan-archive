$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing

$null = [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.RandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

$imagePath = "c:\Users\ETPau\.trae-cn\attachments\6a97bfcc6e8a8001835553f3\dcaf4d78-30ac-4ddf-9bea-8e3e57e5603b_4a03a7a3-3636-4f13-9194-78deb7b27928_image.png"

function Do-Ocr([System.Drawing.Bitmap]$bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $ms.Position = 0
    $winrtStream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($ms)
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($winrtStream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $softBitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language("zh-Hans-CN")))
    if ($null -eq $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
    $ocrResult = Await ($engine.RecognizeAsync($softBitmap)) ([Windows.Media.Ocr.OcrResult])
    return $ocrResult
}

function Get-Coord($word) {
    try {
        $r = $word.BoundingRect
        $j = ($r | ConvertTo-Json -Depth 2 -Compress) | ConvertFrom-Json
        if ($null -ne $j.X -and $null -ne $j.Y) {
            return @{ X = [double]$j.X; Y = [double]$j.Y }
        }
    } catch { }
    return $null
}

try {
    $src = [System.Drawing.Image]::FromFile($imagePath)

    # Regions of interest (in source pixel coordinates, image is 2864x1536)
    # The resume page appears to span roughly X 1060-1830, Y 120-1520
    $regions = @(
        @{ Name = "PAGE-FULL-3x"; X = 1040; Y = 100;  W = 800;  H = 1430; Scale = 3.0 }
    )

    foreach ($q in $regions) {
        $scale = $q.Scale
        $newW = [int]($q.W * $scale)
        $newH = [int]($q.H * $scale)
        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $newW, $newH)), (New-Object System.Drawing.Rectangle($q.X, $q.Y, $q.W, $q.H)), [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose()

        Write-Output ("===== REGION: " + $q.Name + " =====")
        $result = Do-Ocr $bmp
        foreach ($line in $result.Lines) {
            $text = $line.Text
            $coordStr = "[??] "
            foreach ($word in $line.Words) {
                $c = Get-Coord $word
                if ($null -ne $c) {
                    $coordStr = "[srcY~" + [int][math]::Round($q.Y + ($c.Y / $scale)) + " srcX~" + [int][math]::Round($q.X + ($c.X / $scale)) + "] "
                    break
                }
            }
            Write-Output ($coordStr + $text)
        }
        $bmp.Dispose()
    }

    # Also OCR with English engine for the mixed-language summary area
    Write-Output ""
    Write-Output "===== ENGLISH OCR on summary area (X 1060-1840, Y 140-260, 4x) ====="
    $scale = 4.0
    $qX = 1060; $qY = 140; $qW = 780; $qH = 130
    $newW = [int]($qW * $scale); $newH = [int]($qH * $scale)
    $bmp2 = New-Object System.Drawing.Bitmap($newW, $newH)
    $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $newW, $newH)), (New-Object System.Drawing.Rectangle($qX, $qY, $qW, $qH)), [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp2.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $ms.Position = 0
    $winrtStream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($ms)
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($winrtStream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $softBitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $lang = New-Object Windows.Globalization.Language("en-US")
    if ([Windows.Media.Ocr.OcrEngine]::IsLanguageSupported($lang)) {
        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
        $ocrResult = Await ($engine.RecognizeAsync($softBitmap)) ([Windows.Media.Ocr.OcrResult])
        foreach ($line in $ocrResult.Lines) {
            Write-Output $line.Text
        }
    } else {
        Write-Output "en-US OCR not supported"
    }
    $bmp2.Dispose()

    $src.Dispose()
}
catch {
    Write-Output ("ERROR: " + $_.Exception.Message)
    Write-Output ($_.Exception.ToString())
}
