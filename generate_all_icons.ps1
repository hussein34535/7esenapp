Add-Type -AssemblyName System.Drawing

$sourcePath = "assets\icon\icon.png"

if (-not (Test-Path $sourcePath)) {
    Write-Host "Error: Source file not found."
    exit
}

function Generate-Icon($size, $outputPath) {
    # Create a new bitmap (transparent default if source is transparent)
    $bitmap = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Ensure background is transparent
    $graphics.Clear([System.Drawing.Color]::Transparent) 
    
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    # Load source image
    $sourceImage = [System.Drawing.Image]::FromFile($sourcePath)

    # Use full dimensions (no padding)
    $paddingScale = 1.0 # Changed to 1.0
    $maxDim = $size * $paddingScale
    
    $ratioX = $maxDim / $sourceImage.Width
    $ratioY = $maxDim / $sourceImage.Height
    # If we want to fill the square, we might stretch if aspect ratio differs.
    # Usually icons are square. If not, this logic preserves aspect ratio and centers.
    $ratio = [Math]::Min($ratioX, $ratioY)

    $newWidth = [int]($sourceImage.Width * $ratio)
    $newHeight = [int]($sourceImage.Height * $ratio)

    # Center the image
    $x = ($size - $newWidth) / 2
    $y = ($size - $newHeight) / 2

    # Draw the source image onto the bitmap
    $graphics.DrawImage($sourceImage, $x, $y, $newWidth, $newHeight)

    # Save the result
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    # Clean up
    $sourceImage.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "Successfully created $outputPath"
}

# Generate 192x192 icons
Generate-Icon 192 "web\icons\icon-192.png"
Generate-Icon 192 "web\icons\icon-maskable-192.png"

# Generate 512x512 icons
Generate-Icon 512 "web\icons\icon-512.png"
Generate-Icon 512 "web\icons\icon-maskable-512.png"
