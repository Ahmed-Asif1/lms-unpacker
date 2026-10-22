param([Parameter(Mandatory)][string]$OutputPath)
Add-Type -AssemblyName System.Drawing
$frames = @()
foreach ($size in @(16,32,48,256)) {
    $bitmap = [Drawing.Bitmap]::new($size,$size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.Clear([Drawing.Color]::FromArgb(20,99,75))
    $scale = $size / 32.0
    $pen = [Drawing.Pen]::new([Drawing.Color]::White,([single](1.8*$scale)))
    $gold = [Drawing.Pen]::new([Drawing.Color]::FromArgb(245,207,117),([single](2*$scale)))
    $points = [Drawing.PointF[]]@([Drawing.PointF]::new(7*$scale,13*$scale),[Drawing.PointF]::new(13*$scale,13*$scale),[Drawing.PointF]::new(16*$scale,16*$scale),[Drawing.PointF]::new(25*$scale,16*$scale),[Drawing.PointF]::new(25*$scale,26*$scale),[Drawing.PointF]::new(7*$scale,26*$scale),[Drawing.PointF]::new(7*$scale,13*$scale))
    $graphics.DrawLines($pen,$points)
    $graphics.DrawLine($gold,[single](16*$scale),[single](5*$scale),[single](16*$scale),[single](18*$scale))
    $graphics.DrawLine($gold,[single](12*$scale),[single](14*$scale),[single](16*$scale),[single](18*$scale))
    $graphics.DrawLine($gold,[single](20*$scale),[single](14*$scale),[single](16*$scale),[single](18*$scale))
    $buffer = [IO.MemoryStream]::new()
    $bitmap.Save($buffer,[Drawing.Imaging.ImageFormat]::Png)
    $frames += [pscustomobject]@{Size=$size; Bytes=$buffer.ToArray()}
    $buffer.Dispose(); $gold.Dispose(); $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$output = [IO.File]::Create($OutputPath)
$writer = [IO.BinaryWriter]::new($output)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
    $offset = 6 + 16*$frames.Count
    foreach ($frame in $frames) {
        $dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset)
        $offset += $frame.Bytes.Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
} finally { $writer.Dispose(); $output.Dispose() }
