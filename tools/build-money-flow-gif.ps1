param(
  [string]$Source = "$PSScriptRoot\..\assets\bellionaire-money-flow-market.png",
  [string]$Output = "$PSScriptRoot\..\assets\bellionaire-money-flow-stream.gif"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-ImagePropertyItem {
  param([int]$Id, [int16]$Type, [byte[]]$Value)
  $item = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject([System.Drawing.Imaging.PropertyItem])
  $item.Id = $Id
  $item.Type = $Type
  $item.Len = $Value.Length
  $item.Value = $Value
  return $item
}

$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Source))
$frames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
$frameCount = 18
$width = 800
$height = 450

try {
  for ($index = 0; $index -lt $frameCount; $index++) {
    $frame = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($frame)
    try {
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $destination = [System.Drawing.RectangleF]::new(0, 0, $width, $height)
      $sourceRect = [System.Drawing.RectangleF]::new(0, 0, $sourceImage.Width, $sourceImage.Height)
      # The base image is drawn identically in every frame. Only the gold pulses below move.
      $graphics.DrawImage($sourceImage, $destination, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)

      for ($pulse = 0; $pulse -lt 6; $pulse++) {
        $progress = (($index / $frameCount) + ($pulse / 6.0)) % 1.0
        $x = [float](-35 + (($width + 70) * $progress))
        $y = [float](405 - (330 * $progress) + (22 * [Math]::Sin($progress * 3 * [Math]::PI)))

        $glowPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $glowPath.AddEllipse($x - 35, $y - 16, 70, 32)
        $glowBrush = [System.Drawing.Drawing2D.PathGradientBrush]::new($glowPath)
        try {
          $glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(150, 255, 232, 153)
          $glowBrush.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 214, 167, 76))
          $graphics.FillPath($glowBrush, $glowPath)
        } finally {
          $glowBrush.Dispose()
          $glowPath.Dispose()
        }

        $streakPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(115, 255, 228, 137), 2.2)
        try { $graphics.DrawLine($streakPen, $x - 24, $y + 10, $x + 24, $y - 10) } finally { $streakPen.Dispose() }

        $sparkBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(220, 255, 241, 185))
        try { $graphics.FillEllipse($sparkBrush, $x - 2.5, $y - 2.5, 5, 5) } finally { $sparkBrush.Dispose() }
      }
    } finally {
      $graphics.Dispose()
    }
    $frames.Add($frame)
  }

  $delays = [byte[]]::new($frameCount * 4)
  for ($index = 0; $index -lt $frameCount; $index++) {
    [BitConverter]::GetBytes([int]7).CopyTo($delays, $index * 4)
  }

  $frames[0].SetPropertyItem((New-ImagePropertyItem -Id 0x5100 -Type 4 -Value $delays))
  $frames[0].SetPropertyItem((New-ImagePropertyItem -Id 0x5101 -Type 3 -Value ([BitConverter]::GetBytes([uint16]0))))

  $gifCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/gif' | Select-Object -First 1
  $saveFlag = [System.Drawing.Imaging.Encoder]::SaveFlag
  $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
  $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($saveFlag, [long][System.Drawing.Imaging.EncoderValue]::MultiFrame)
  $frames[0].Save($Output, $gifCodec, $parameters)

  $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($saveFlag, [long][System.Drawing.Imaging.EncoderValue]::FrameDimensionTime)
  for ($index = 1; $index -lt $frameCount; $index++) {
    $frames[0].SaveAdd($frames[$index], $parameters)
  }

  $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($saveFlag, [long][System.Drawing.Imaging.EncoderValue]::Flush)
  $frames[0].SaveAdd($parameters)
  $parameters.Dispose()
} finally {
  foreach ($frame in $frames) { $frame.Dispose() }
  $sourceImage.Dispose()
}

$result = [System.Drawing.Image]::FromFile($Output)
try {
  $frameDimension = [System.Drawing.Imaging.FrameDimension]::new($result.FrameDimensionsList[0])
  Write-Output "Created $Output ($($result.GetFrameCount($frameDimension)) frames, $($result.Width)x$($result.Height))"
} finally {
  $result.Dispose()
}
