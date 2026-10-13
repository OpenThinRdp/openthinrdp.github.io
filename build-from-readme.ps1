# Builds index.html of https://openthinrdp.github.io/ from the README published on GitHub, so the site is never a
# second copy of the documentation: the README text rendered by GitHub itself, links pointing to the repository.
# Run it after every release (or README change), then commit and push this folder.
#   powershell -ExecutionPolicy Bypass -File build-from-readme.ps1
$ErrorActionPreference = 'Stop'
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$repo = 'OpenThinRdp/openthinrdp'; $blob = "https://github.com/$repo/blob/main"; $raw = "https://raw.githubusercontent.com/$repo/main"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$md = & $gh api "repos/$repo/readme" -H 'Accept: application/vnd.github.raw'
$tmp = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($tmp, ($md -join "`n"), (New-Object Text.UTF8Encoding $false))
$body = (& $gh api markdown -f mode=gfm -f context=$repo -F "text=@$tmp") -join "`n"
Remove-Item $tmp
$ver = (& $gh api "repos/$repo/releases/latest" --jq .tag_name) -replace '^v', ''
# relative links and images -> the repository on GitHub (anchors inside the page stay)
$body = [regex]::Replace($body, 'href="(?!https?:|#|mailto:)([^"]+)"', { param($m) 'href="' + "$blob/" + $m.Groups[1].Value.TrimStart('./') + '"' })
$body = [regex]::Replace($body, 'src="(?!https?:|data:)([^"]+)"', { param($m) 'src="' + "$raw/" + $m.Groups[1].Value.TrimStart('./') + '"' })
$desc = 'OpenThinRDP: open source thin client operating system for Microsoft Remote Desktop (RDS and VDI), Debian 13 with FreeRDP and the RDP UDP transport. Free, signed updates, central management.'
$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OpenThinRDP – open source thin client OS with RDP over UDP for RDS and VDI</title>
<meta name="description" content="$desc">
<link rel="canonical" href="https://openthinrdp.github.io/">
<link rel="icon" href="img/icon.png">
<meta property="og:type" content="website">
<meta property="og:title" content="OpenThinRDP – open source thin client OS for RDS and VDI">
<meta property="og:description" content="$desc">
<meta property="og:url" content="https://openthinrdp.github.io/">
<meta property="og:image" content="https://openthinrdp.github.io/img/social.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.8.1/github-markdown.min.css">
<link rel="stylesheet" href="style.css">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"SoftwareApplication","name":"OpenThinRDP","applicationCategory":"OperatingSystem",
 "operatingSystem":"Debian 13 (Linux)","softwareVersion":"$ver","license":"https://github.com/$repo/blob/main/LICENSE",
 "offers":{"@type":"Offer","price":"0","priceCurrency":"EUR"},"url":"https://openthinrdp.github.io/",
 "downloadUrl":"https://github.com/$repo/releases/latest","codeRepository":"https://github.com/$repo"}
</script>
</head>
<body>
<header class="bar"><a class="home" href="https://github.com/$repo"><img src="img/icon.png" alt="" width="28" height="28"> OpenThinRDP</a>
<nav><a href="https://github.com/$repo/releases/latest">Download $ver</a><a href="https://github.com/$repo">GitHub</a><a href="https://github.com/$repo/tree/main/docs">Documentation</a></nav></header>
<main class="markdown-body">
$body
</main>
<footer class="bar small">This page is the project README as published on <a href="https://github.com/$repo">GitHub</a>, where the documentation, the releases and the discussions are.</footer>
</body>
</html>
"@
[IO.File]::WriteAllText((Join-Path $here 'index.html'), $html, (New-Object Text.UTF8Encoding $false))
"index.html: README of $repo, release $ver, $([math]::Round($html.Length/1KB)) KB"
