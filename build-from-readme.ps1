# Builds the pages of https://openthinrdp.github.io/ from the documents published on GitHub, so the site is never a
# second copy of the documentation: the text rendered by GitHub itself, links pointing to the repository.
#   index.html    the README
#   manager.html  docs/manager.md, the Windows manager page by page
# Run it after every release (or change of those documents), then commit and push this folder.
#   powershell -ExecutionPolicy Bypass -File build-from-readme.ps1
$ErrorActionPreference = 'Stop'
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$repo = 'OpenThinRdp/openthinrdp'; $blob = "https://github.com/$repo/blob/main"; $raw = "https://raw.githubusercontent.com/$repo/main"
$site = 'https://openthinrdp.github.io/'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ver = (& $gh api "repos/$repo/releases/latest" --jq .tag_name) -replace '^v', ''
# the pages of the site: a link to their document goes to the page instead of GitHub
$pages = @{ 'README.md' = ''; 'docs/manager.md' = 'manager.html' }

# a path relative to the folder of the document, as a path of the repository
function Resolve-RepoPath([string]$dir, [string]$p) {
  $parts = [System.Collections.Generic.List[string]]::new()
  foreach ($s in (($(if ($dir) { "$dir/" } else { '' }) + $p.TrimStart('./')) -split '/')) {
    if ($s -eq '..') { if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) } } elseif ($s -and $s -ne '.') { $parts.Add($s) }
  }
  $parts -join '/'
}

function Build-Page([string]$doc, [string]$out, [string]$title, [string]$desc, [string]$footer) {
  $md = & $gh api "repos/$repo/contents/$doc" -H 'Accept: application/vnd.github.raw'
  $tmp = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($tmp, ($md -join "`n"), (New-Object Text.UTF8Encoding $false))
  $body = (& $gh api markdown -f mode=gfm -f context=$repo -F "text=@$tmp") -join "`n"
  Remove-Item $tmp
  $dir = if ($doc.Contains('/')) { $doc.Substring(0, $doc.LastIndexOf('/')) } else { '' }
  # relative links -> the page of the site when there is one, else the repository on GitHub (anchors inside stay)
  $body = [regex]::Replace($body, 'href="(?!https?:|#|mailto:)([^"#]*)(#[^"]*)?"', {
    param($m) $p = Resolve-RepoPath $dir $m.Groups[1].Value; $a = $m.Groups[2].Value
    if ($pages.ContainsKey($p)) { 'href="' + $site + $pages[$p] + $a + '"' } else { 'href="' + "$blob/$p$a" + '"' } })
  $body = [regex]::Replace($body, 'src="(?!https?:|data:)([^"]+)"', { param($m) 'src="' + "$raw/" + (Resolve-RepoPath $dir $m.Groups[1].Value) + '"' })
  # the API gives the headings no id (GitHub's own page adds them with a script): the same ids as on GitHub, so
  # that #anchors inside the page and from other pages work
  $seen = @{}
  $body = [regex]::Replace($body, '<h([1-6]) dir="auto">(.*?)</h\1>', {
    param($m) $t = [Net.WebUtility]::HtmlDecode(($m.Groups[2].Value -replace '<[^>]+>', '')).Trim().ToLowerInvariant()
    $s = (($t -replace '[^\p{L}\p{Nd}\s_-]', '') -replace '\s', '-')
    if ($seen.ContainsKey($s)) { $seen[$s]++; $s = "$s-$($seen[$s])" } else { $seen[$s] = 0 }
    "<h$($m.Groups[1].Value) id=`"$s`" dir=`"auto`">$($m.Groups[2].Value)</h$($m.Groups[1].Value)>" }, 'Singleline')
  $url = $site + $(if ($out -eq 'index.html') { '' } else { $out })
  $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<meta name="description" content="$desc">
<link rel="canonical" href="$url">
<link rel="icon" href="img/icon.png">
<meta property="og:type" content="website">
<meta property="og:title" content="$title">
<meta property="og:description" content="$desc">
<meta property="og:url" content="$url">
<meta property="og:image" content="${site}img/social.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.8.1/github-markdown.min.css">
<link rel="stylesheet" href="style.css">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"SoftwareApplication","name":"OpenThinRDP","applicationCategory":"OperatingSystem",
 "operatingSystem":"Debian 13 (Linux)","softwareVersion":"$ver","license":"https://github.com/$repo/blob/main/LICENSE",
 "offers":{"@type":"Offer","price":"0","priceCurrency":"EUR"},"url":"$site",
 "downloadUrl":"https://github.com/$repo/releases/latest","codeRepository":"https://github.com/$repo"}
</script>
</head>
<body>
<header class="bar"><a class="home" href="$site"><img src="img/icon.png" alt="" width="28" height="28"> OpenThinRDP</a>
<nav><a href="https://github.com/$repo/releases/latest">Download $ver</a><a href="${site}manager.html">Manager</a><a href="https://github.com/$repo">GitHub</a><a href="https://github.com/$repo/tree/main/docs">Documentation</a></nav></header>
<main class="markdown-body">
$body
</main>
<footer class="bar small">$footer</footer>
</body>
</html>
"@
  [IO.File]::WriteAllText((Join-Path $here $out), $html, (New-Object Text.UTF8Encoding $false))
  "${out}: $doc of $repo, release $ver, $([math]::Round($html.Length/1KB)) KB"
}

Build-Page 'README.md' 'index.html' 'OpenThinRDP – open source thin client OS with RDP over UDP for RDS and VDI' `
  'OpenThinRDP: open source thin client operating system for Microsoft Remote Desktop (RDS and VDI), Debian 13 with FreeRDP and the RDP UDP transport. Free, signed updates, central management.' `
  "This page is the project README as published on <a href=`"https://github.com/$repo`">GitHub</a>, where the documentation, the releases and the discussions are."
Build-Page 'docs/manager.md' 'manager.html' 'OpenThinRDP manager – the whole thin client fleet from one window' `
  'The OpenThinRDP manager for Windows: every thin client at a glance, central settings, a new version on pilot devices first, going back to an earlier version for the whole fleet, remote screen, signed updates.' `
  "This page is <a href=`"$blob/docs/manager.md`">docs/manager.md</a> as published on <a href=`"https://github.com/$repo`">GitHub</a>."
