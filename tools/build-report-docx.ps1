param(
  [string]$MarkdownPath = "$PSScriptRoot\..\BAO_CAO_WEBSITE_BELLIONAIRE.md",
  [string]$OutputPath = "$PSScriptRoot\..\BAO_CAO_WEBSITE_BELLIONAIRE.docx"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.Drawing

$workspace = (Resolve-Path -LiteralPath "$PSScriptRoot\..").Path
$markdown = Get-Content -LiteralPath (Resolve-Path -LiteralPath $MarkdownPath) -Encoding UTF8
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bellionaire-docx-" + [Guid]::NewGuid().ToString('N'))
$wordRoot = Join-Path $tempRoot 'word'
$mediaRoot = Join-Path $wordRoot 'media'
$wordRelsRoot = Join-Path $wordRoot '_rels'

New-Item -ItemType Directory -Path $tempRoot,$wordRoot,$mediaRoot,$wordRelsRoot,(Join-Path $tempRoot '_rels'),(Join-Path $tempRoot 'docProps') -Force | Out-Null

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
function Write-Utf8File([string]$Path, [string]$Content) {
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Escape-Xml([string]$Text) {
  if ($null -eq $Text) { return '' }
  return [System.Security.SecurityElement]::Escape($Text)
}

function New-Run([string]$Text, [bool]$Bold = $false, [bool]$Code = $false, [bool]$Italic = $false) {
  $properties = ''
  if ($Bold -or $Code -or $Italic) {
    $parts = [System.Collections.Generic.List[string]]::new()
    if ($Bold) { $parts.Add('<w:b/>') }
    if ($Italic) { $parts.Add('<w:i/>') }
    if ($Code) { $parts.Add('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:color w:val="8B6228"/>') }
    $properties = '<w:rPr>' + ($parts -join '') + '</w:rPr>'
  }
  return '<w:r>' + $properties + '<w:t xml:space="preserve">' + (Escape-Xml $Text) + '</w:t></w:r>'
}

function Convert-Inline([string]$Text) {
  $clean = $Text.TrimEnd()
  $pattern = '\*\*(.+?)\*\*|`([^`]+)`'
  $matches = [regex]::Matches($clean, $pattern)
  if ($matches.Count -eq 0) { return New-Run $clean }

  $runs = [System.Collections.Generic.List[string]]::new()
  $position = 0
  foreach ($match in $matches) {
    if ($match.Index -gt $position) {
      $runs.Add((New-Run $clean.Substring($position, $match.Index - $position)))
    }
    if ($match.Groups[1].Success) {
      $runs.Add((New-Run $match.Groups[1].Value $true))
    } else {
      $runs.Add((New-Run $match.Groups[2].Value $false $true))
    }
    $position = $match.Index + $match.Length
  }
  if ($position -lt $clean.Length) {
    $runs.Add((New-Run $clean.Substring($position)))
  }
  return $runs -join ''
}

function New-Paragraph([string]$Text, [string]$Style = 'Normal', [string]$Alignment = '') {
  $paragraphProperties = '<w:pStyle w:val="' + $Style + '"/>'
  if ($Alignment) { $paragraphProperties += '<w:jc w:val="' + $Alignment + '"/>' }
  return '<w:p><w:pPr>' + $paragraphProperties + '</w:pPr>' + (Convert-Inline $Text) + '</w:p>'
}

function New-Table([array]$Rows) {
  $table = [System.Collections.Generic.List[string]]::new()
  $table.Add('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="5" w:color="C9B47A"/><w:left w:val="single" w:sz="5" w:color="D7D7D2"/><w:bottom w:val="single" w:sz="5" w:color="C9B47A"/><w:right w:val="single" w:sz="5" w:color="D7D7D2"/><w:insideH w:val="single" w:sz="4" w:color="D7D7D2"/><w:insideV w:val="single" w:sz="4" w:color="D7D7D2"/></w:tblBorders></w:tblPr>')
  for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
    $table.Add('<w:tr>')
    foreach ($cellText in $Rows[$rowIndex]) {
      $shade = if ($rowIndex -eq 0) { '<w:shd w:fill="EEE9DB"/>' } else { '' }
      $run = if ($rowIndex -eq 0) { New-Run $cellText $true } else { Convert-Inline $cellText }
      $table.Add('<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/>' + $shade + '</w:tcPr><w:p><w:pPr><w:spacing w:after="60"/></w:pPr>' + $run + '</w:p></w:tc>')
    }
    $table.Add('</w:tr>')
  }
  $table.Add('</w:tbl>')
  return $table -join ''
}

$body = [System.Collections.Generic.List[string]]::new()
$imageRelationships = [System.Collections.Generic.List[string]]::new()
$imageIndex = 0
$drawingId = 1
$pageBreakAdded = $false

function Add-Image([string]$Alt, [string]$RelativePath) {
  $script:imageIndex++
  $sourcePath = Join-Path $workspace ($RelativePath -replace '/', '\')
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    $script:body.Add((New-Paragraph "[Missing image: $RelativePath]" 'Caption' 'center'))
    return
  }

  $extension = [System.IO.Path]::GetExtension($sourcePath).TrimStart('.').ToLowerInvariant()
  $mediaName = "image$($script:imageIndex).$extension"
  Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $mediaRoot $mediaName)
  $relationshipId = "rId$($script:imageIndex + 10)"
  $script:imageRelationships.Add('<Relationship Id="' + $relationshipId + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/' + $mediaName + '"/>')

  $image = [System.Drawing.Image]::FromFile($sourcePath)
  try {
    $maxWidth = 5943600
    $height = [long]($maxWidth * $image.Height / $image.Width)
  } finally {
    $image.Dispose()
  }

  $safeAlt = Escape-Xml $Alt
  $drawing = @"
<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="120" w:after="80"/></w:pPr><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$maxWidth" cy="$height"/><wp:docPr id="$drawingId" name="$safeAlt" descr="$safeAlt"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="0" name="$mediaName"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$relationshipId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$maxWidth" cy="$height"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>
"@
  $script:body.Add($drawing)
  $script:body.Add((New-Paragraph $Alt 'Caption' 'center'))
  $script:drawingId++
}

$index = 0
while ($index -lt $markdown.Count) {
  $line = $markdown[$index]

  if ($line -match '^!\[(.*?)\]\((.*?)\)$') {
    Add-Image $Matches[1] $Matches[2]
    $index++
    continue
  }

  if ($line -match '^\|.*\|$' -and ($index + 1) -lt $markdown.Count -and $markdown[$index + 1] -match '^\|[\s:|\-]+\|$') {
    $rows = [System.Collections.Generic.List[object]]::new()
    $headerCells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    $rows.Add($headerCells)
    $index += 2
    while ($index -lt $markdown.Count -and $markdown[$index] -match '^\|.*\|$') {
      $rows.Add(@($markdown[$index].Trim('|').Split('|') | ForEach-Object { $_.Trim() }))
      $index++
    }
    $body.Add((New-Table $rows))
    continue
  }

  if ($line -eq '---') {
    if (-not $pageBreakAdded) {
      $body.Add('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
      $pageBreakAdded = $true
    }
    $index++
    continue
  }

  if ($line -match '^# (.+)$') {
    $body.Add((New-Paragraph $Matches[1] 'Title' 'center'))
  } elseif ($line -match '^## (.+)$') {
    $body.Add((New-Paragraph $Matches[1] 'Heading1'))
  } elseif ($line -match '^### (.+)$') {
    $body.Add((New-Paragraph $Matches[1] 'Heading2'))
  } elseif ($line -match '^\- (.+)$') {
    $body.Add((New-Paragraph ('- ' + $Matches[1]) 'ListParagraph'))
  } elseif ($line -match '^\d+\. (.+)$') {
    $body.Add((New-Paragraph $line 'ListParagraph'))
  } elseif ([string]::IsNullOrWhiteSpace($line)) {
    $body.Add('<w:p/>')
  } else {
    $body.Add((New-Paragraph $line))
  }
  $index++
}

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$($body -join '')<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>
"@

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="22"/><w:lang w:val="vi-VN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="140" w:line="276" w:lineRule="auto"/><w:jc w:val="both"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:spacing w:before="1200" w:after="360"/><w:jc w:val="center"/></w:pPr><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:b/><w:color w:val="8B6228"/><w:sz w:val="38"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="300" w:after="140"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:b/><w:color w:val="765323"/><w:sz w:val="30"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="220" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:color w:val="333730"/><w:sz w:val="25"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="360" w:hanging="180"/></w:pPr></w:style><w:style w:type="paragraph" w:styleId="Caption"><w:name w:val="Caption"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="180"/><w:jc w:val="center"/></w:pPr><w:rPr><w:i/><w:color w:val="666A63"/><w:sz w:val="18"/></w:rPr></w:style></w:styles>
'@

$contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="gif" ContentType="image/gif"/><Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="jpeg" ContentType="image/jpeg"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>
'@

$rootRelationships = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
'@

$documentRelationships = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' + ($imageRelationships -join '') + '</Relationships>'
$timestamp = [DateTime]::UtcNow.ToString('s') + 'Z'
$coreXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>B&#225;o c&#225;o Website Bellionaire</dc:title><dc:subject>C&#244;ng ngh&#7879; &#273;a ph&#432;&#417;ng ti&#7879;n</dc:subject><dc:creator>Bellionaire</dc:creator><cp:keywords>website, multimedia, image, GIF, video</cp:keywords><dcterms:created xsi:type="dcterms:W3CDTF">' + $timestamp + '</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">' + $timestamp + '</dcterms:modified></cp:coreProperties>'
$appXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Microsoft Office Word</Application><DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop><Company>Bellionaire</Company><AppVersion>16.0000</AppVersion></Properties>'

Write-Utf8File (Join-Path $tempRoot '[Content_Types].xml') $contentTypes
Write-Utf8File (Join-Path $tempRoot '_rels\.rels') $rootRelationships
Write-Utf8File (Join-Path $wordRoot 'document.xml') $documentXml
Write-Utf8File (Join-Path $wordRoot 'styles.xml') $stylesXml
Write-Utf8File (Join-Path $wordRelsRoot 'document.xml.rels') $documentRelationships
Write-Utf8File (Join-Path $tempRoot 'docProps\core.xml') $coreXml
Write-Utf8File (Join-Path $tempRoot 'docProps\app.xml') $appXml

try {
  $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
  if (Test-Path -LiteralPath $resolvedOutput) { Remove-Item -LiteralPath $resolvedOutput -Force }
  $outputStream = [System.IO.File]::Open($resolvedOutput, [System.IO.FileMode]::CreateNew)
  try {
    $archive = [System.IO.Compression.ZipArchive]::new($outputStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
      foreach ($file in Get-ChildItem -LiteralPath $tempRoot -File -Recurse) {
        $entryName = $file.FullName.Substring($tempRoot.Length + 1).Replace('\', '/')
        $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $inputStream = [System.IO.File]::OpenRead($file.FullName)
        try { $inputStream.CopyTo($entryStream) } finally { $inputStream.Dispose(); $entryStream.Dispose() }
      }
    } finally { $archive.Dispose() }
  } finally { $outputStream.Dispose() }
  Write-Output "Created: $resolvedOutput"
} finally {
  if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
