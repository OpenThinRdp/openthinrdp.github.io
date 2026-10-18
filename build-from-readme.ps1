# Builds https://openthinrdp.github.io/ from the documents published on GitHub, so the site is never a second copy
# of the documentation: the text rendered by GitHub itself, links pointing to the pages of the site or to GitHub.
#   index.html          the README
#   manager.html        docs/manager.md      the Windows manager, page by page
#   faq.html            docs/faq.md          questions and answers (with FAQPage structured data)
#   alternatives.html   docs/alternatives.md compared with Mint + Remmina, IGEL OS, ThinOS, Stratodesk...
#   hardware.html       docs/hardware.md     drivers, requirements, tested and expected devices
#   udp.html            docs/udp.md          the RDP UDP transport and its measurements
#   llms-full.txt       the main documents whole, for AI assistants; sitemap.xml
# Run it after every release (or change of those documents), then commit and push this folder.
#   powershell -ExecutionPolicy Bypass -File build-from-readme.ps1
$ErrorActionPreference = 'Stop'
# the output of gh is UTF-8: read with the console code page (850, 437...) every accented letter, dash, x and arrow came out garbled
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$utf8 = New-Object Text.UTF8Encoding $false
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$repo = 'OpenThinRdp/openthinrdp'; $blob = "https://github.com/$repo/blob/main"; $raw = "https://raw.githubusercontent.com/$repo/main"
$site = 'https://openthinrdp.github.io/'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ver = (& $gh api "repos/$repo/releases/latest" --jq .tag_name) -replace '^v', ''
$today = Get-Date -Format 'yyyy-MM-dd'
# the pages of the site: a link to their document goes to the page instead of GitHub
$pages = [ordered]@{ 'README.md' = ''; 'docs/manager.md' = 'manager.html'; 'docs/faq.md' = 'faq.html'
  'docs/alternatives.md' = 'alternatives.html'; 'docs/hardware.md' = 'hardware.html'; 'docs/udp.md' = 'udp.html' }
# the documents an AI assistant should read whole, in llms-full.txt, in this order
$fullDocs = 'README.md', 'docs/faq.md', 'docs/alternatives.md', 'docs/hardware.md', 'docs/status.md', 'docs/manager.md',
  'docs/configuration.md', 'docs/management.md', 'docs/udp.md', 'docs/security.md'

function Get-Doc([string]$doc) { (& $gh api "repos/$repo/contents/$doc" -H 'Accept: application/vnd.github.raw') -join "`n" }

# a path relative to the folder of the document, as a path of the repository
function Resolve-RepoPath([string]$dir, [string]$p) {
  $parts = [System.Collections.Generic.List[string]]::new()
  foreach ($s in (($(if ($dir) { "$dir/" } else { '' }) + $p.TrimStart('./')) -split '/')) {
    if ($s -eq '..') { if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) } } elseif ($s -and $s -ne '.') { $parts.Add($s) }
  }
  $parts -join '/'
}

# FAQPage structured data from a document made of "### question" and its answer: the answer as plain text
function Get-FaqJson([string]$md) {
  $items = foreach ($m in [regex]::Matches($md, '(?ms)^### (.+?)\r?\n(.+?)(?=^#{1,3} |\z)')) {
    $a = (($m.Groups[2].Value -replace '\[([^\]]+)\]\([^)]+\)', '$1') -replace '[`*]', '') -replace '\s+', ' '
    [ordered]@{ '@type' = 'Question'; name = $m.Groups[1].Value.Trim(); acceptedAnswer = [ordered]@{ '@type' = 'Answer'; text = $a.Trim() } }
  }
  ConvertTo-Json ([ordered]@{ '@context' = 'https://schema.org'; '@type' = 'FAQPage'; mainEntity = @($items) }) -Depth 6 -Compress
}

function Build-Page([string]$doc, [string]$title, [string]$desc, [string]$footer, [switch]$Faq) {
  $out = if ($pages[$doc]) { $pages[$doc] } else { 'index.html' }
  $md = Get-Doc $doc
  $tmp = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($tmp, $md, $utf8)
  $body = (& $gh api markdown -f mode=gfm -f context=$repo -F "text=@$tmp") -join "`n"
  Remove-Item $tmp
  $dir = if ($doc.Contains('/')) { $doc.Substring(0, $doc.LastIndexOf('/')) } else { '' }
  # relative links -> the page of the site when there is one, else the repository on GitHub (anchors inside stay)
  $body = [regex]::Replace($body, 'href="(?!https?:|#|mailto:)([^"#]*)(#[^"]*)?"', {
    param($m) $p = Resolve-RepoPath $dir $m.Groups[1].Value; $a = $m.Groups[2].Value
    if ($pages.Contains($p)) { 'href="' + $site + $pages[$p] + $a + '"' } else { 'href="' + "$blob/$p$a" + '"' } })
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
  $faqLd = if ($Faq) { "<script type=`"application/ld+json`">" + (Get-FaqJson $md) + "</script>" } else { '' }
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
<link rel="alternate" type="text/plain" href="${site}llms-full.txt" title="The documentation in one text file">
<meta property="og:type" content="website">
<meta property="og:site_name" content="OpenThinRDP">
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
$faqLd
</head>
<body>
<header class="bar"><a class="home" href="$site"><img src="img/icon.png" alt="" width="28" height="28"> OpenThinRDP</a>
<nav><a href="https://github.com/$repo/releases/latest">Download $ver</a><a href="${site}manager.html">Manager</a><a href="${site}hardware.html">Hardware</a><a href="${site}alternatives.html">Compare</a><a href="${site}faq.html">FAQ</a><a href="https://github.com/$repo">GitHub</a></nav></header>
<main class="markdown-body">
$body
</main>
<footer class="bar small">$footer</footer>
</body>
</html>
"@
  [IO.File]::WriteAllText((Join-Path $here $out), $html, $utf8)
  "${out}: $doc, release $ver, $([math]::Round($html.Length/1KB)) KB"
}
function Footer([string]$doc) { "This page is <a href=`"$blob/$doc`">$doc</a> as published on <a href=`"https://github.com/$repo`">GitHub</a>, where the documentation, the releases and the discussions are." }

Build-Page 'README.md' 'OpenThinRDP &#8211; open source thin client OS with RDP over UDP for RDS and VDI' `
  'OpenThinRDP: free, open source thin client operating system for Microsoft Remote Desktop (RDS and VDI), on premises or in the cloud. Debian 13 with FreeRDP and the RDP UDP transport, a kiosk sign-in, central management from a shared folder, signed updates with pilot devices and rollback.' `
  "This page is the project README as published on <a href=`"https://github.com/$repo`">GitHub</a>, where the documentation, the releases and the discussions are."
Build-Page 'docs/manager.md' 'OpenThinRDP manager &#8211; the whole thin client fleet from one window' `
  'The OpenThinRDP manager for Windows: every thin client at a glance, central settings, a new version on pilot devices first, going back to an earlier version for the whole fleet, remote screen, signed updates. No server.' (Footer 'docs/manager.md')
Build-Page 'docs/faq.md' 'OpenThinRDP FAQ &#8211; hardware, drivers, RDP over UDP, Azure, PXE, 802.1X' `
  'Questions and answers about OpenThinRDP, the free thin client OS for Microsoft Remote Desktop: which hardware, drivers, RDP over UDP, RDS and VDI, Azure Virtual Desktop, management without a server, updates and rollback, PXE, 802.1X.' (Footer 'docs/faq.md') -Faq
Build-Page 'docs/alternatives.md' 'OpenThinRDP compared with Linux Mint + Remmina, IGEL OS, Dell ThinOS, Stratodesk, ThinStation' `
  'A free alternative to IGEL OS, Dell ThinOS, Stratodesk NoTouch, ThinStation and openthinclient for Windows Remote Desktop, and why not just Linux Mint with Remmina: RDP over UDP, a locked kiosk, central management, signed updates with rollback.' (Footer 'docs/alternatives.md')
Build-Page 'docs/hardware.md' 'OpenThinRDP hardware &#8211; drivers, requirements, thin clients that run it' `
  'Hardware for OpenThinRDP: any 64-bit x86 PC or thin client, UEFI or legacy BIOS, with the complete Debian 13 kernel and firmware. Tested devices, used thin clients that meet the requirements (Dell Wyse, HP t-series, Fujitsu Futro), firmware settings.' (Footer 'docs/hardware.md')
Build-Page 'docs/udp.md' 'RDP over UDP on Linux &#8211; the FreeRDP UDP transport in OpenThinRDP' `
  'RDP over UDP on Linux with FreeRDP: the UDP transport (MS-RDPEUDP, pull request 13608) built and shipped by OpenThinRDP, what travels over UDP, the fixes we found and the measurements with packet loss against TCP.' (Footer 'docs/udp.md')

# llms-full.txt: the documents whole (llmstxt.org), for assistants that read one file instead of crawling
$full = "# OpenThinRDP: the documentation in one file`n`nSource: https://github.com/$repo (main), release $ver, built $today. Every section below is one file of the repository.`n"
foreach ($d in $fullDocs) { $full += "`n`n---`n`n<!-- $blob/$d -->`n`n" + (Get-Doc $d) }
[IO.File]::WriteAllText((Join-Path $here 'llms-full.txt'), $full, $utf8)
"llms-full.txt: $($fullDocs.Count) documents, $([math]::Round($full.Length/1KB)) KB"

# sitemap.xml: every page, today
$urls = foreach ($p in $pages.Values) { $pr = if ($p) { '0.8' } else { '1.0' }; "  <url><loc>$site$p</loc><lastmod>$today</lastmod><priority>$pr</priority></url>" }
$urls += "  <url><loc>${site}llms-full.txt</loc><lastmod>$today</lastmod><priority>0.3</priority></url>"
[IO.File]::WriteAllText((Join-Path $here 'sitemap.xml'), "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n" + ($urls -join "`n") + "`n</urlset>`n", $utf8)
'sitemap.xml written'
