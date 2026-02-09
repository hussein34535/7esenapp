Add-Type -AssemblyName System.Drawing

$sourcePath = "assets\icon\logo.png"
$outputPath = "web\apple-touch-icon-v3.png"
$targetSize = 192

if (-not (Test-Path $sourcePath)) {
    Write-Host "Error: Source file not found."
    exit
}

# Create a new 192x192 bitmap with black background
$bitmap = New-Object System.Drawing.Bitmap $targetSize, $targetSize
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::Black)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

# Load source image
$sourceImage = [System.Drawing.Image]::FromFile($sourcePath)

# Calculate dimensions to fit within 150x150 (padding)
$maxWidth = 150
$maxHeight = 150
$ratioX = $maxWidth / $sourceImage.Width
$ratioY = $maxHeight / $sourceImage.Height
$ratio = [Math]::Min($ratioX, $ratioY)

$newWidth = [int]($sourceImage.Width * $ratio)
$newHeight = [int]($sourceImage.Height * $ratio)

# Center the image
$x = ($targetSize - $newWidth) / 2
$y = ($targetSize - $newHeight) / 2

# Draw the source image onto the black background
$graphics.DrawImage($sourceImage, $x, $y, $newWidth, $newHeight)

# Save the result
$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up
$sourceImage.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "Successfully created $outputPath"
