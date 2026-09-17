$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Runtime.WindowsRuntime

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

try {
    $bytes = [System.IO.File]::ReadAllBytes($imagePath)
    $memoryStream = New-Object System.IO.MemoryStream(,$bytes)
    $winrtStream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($memoryStream)
    $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($winrtStream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $softBitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language("zh-Hans-CN")))
    if ($null -eq $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
    $ocrResult = Await ($engine.RecognizeAsync($softBitmap)) ([Windows.Media.Ocr.OcrResult])

    # Diagnose the structure of the first word with a bounding rect
    $found = $false
    foreach ($line in $ocrResult.Lines) {
        foreach ($word in $line.Words) {
            $r = $word.BoundingRect
            Write-Output ("Word text: " + $word.Text)
            Write-Output ("Rect type: " + $r.GetType().FullName)
            Write-Output ("Rect ToString: " + $r.ToString())
            $json = $r | ConvertTo-Json -Depth 3
            Write-Output ("Rect JSON: " + $json)
            $found = $true
            break
        }
        if ($found) { break }
    }
}
catch {
    Write-Output ("ERROR: " + $_.Exception.Message)
    Write-Output ($_.Exception.ToString())
}
