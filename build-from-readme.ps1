# Builds https://openthinrdp.github.io/ from the documents published on GitHub, so the site is never a second copy
# of the documentation: the text rendered by GitHub itself, links pointing to the pages of the site or to GitHub.
# The pages are listed in $site_pages below. English only (decided 13/10): it/ and it/faq.html only redirect, because a
# translation lags behind and says wrong things. Then llms-full.txt (the main documents whole, for AI assistants) and sitemap.xml.
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
$dash = '&#8211;'   # PowerShell 5.1 reads this file as ANSI: no non-ASCII characters in it

# Doc = file of the repository; Url = its address on the site ('' = home, a folder ends with /); Alt = the same page in
# the other language; Faq = FAQPage structured data from its "### question" sections
$site_pages = @(
  @{ Doc = 'README.md'; Url = ''; Lang = 'en'
     Title = "OpenThinRDP $dash open source thin client OS with RDP over UDP for RDS and VDI"
     Desc = 'OpenThinRDP: free, open source thin client operating system for Microsoft Remote Desktop (RDS and VDI), on premises or in the cloud. Debian 13 with FreeRDP and the RDP UDP transport, a kiosk sign-in, central management from a shared folder, signed updates with pilot devices and rollback.' }
  @{ Doc = 'docs/manager.md'; Url = 'manager.html'; Lang = 'en'
     Title = "OpenThinRDP manager $dash the whole thin client fleet from one window"
     Desc = 'The OpenThinRDP manager for Windows: every thin client at a glance, central settings, a new version on pilot devices first, going back to an earlier version for the whole fleet, remote screen, signed updates. No server.' }
  @{ Doc = 'docs/faq.md'; Url = 'faq.html'; Lang = 'en'; Faq = $true
     Title = "OpenThinRDP FAQ $dash hardware, drivers, RDP over UDP, Azure, PXE, 802.1X"
     Desc = 'Questions and answers about OpenThinRDP, the free thin client OS for Microsoft Remote Desktop: which hardware, drivers, RDP over UDP, RDS and VDI, Azure Virtual Desktop, management without a server, updates and rollback, PXE, 802.1X.' }
  @{ Doc = 'docs/alternatives.md'; Url = 'alternatives.html'; Lang = 'en'
     Title = 'OpenThinRDP compared with Linux Mint + Remmina, IGEL OS, Dell ThinOS, Stratodesk, ThinStation'
     Desc = 'A free alternative to IGEL OS, Dell ThinOS, Stratodesk NoTouch, ThinStation and openthinclient for Windows Remote Desktop, and why not just Linux Mint with Remmina: RDP over UDP, a locked kiosk, central management, signed updates with rollback.' }
  @{ Doc = 'docs/hardware.md'; Url = 'hardware.html'; Lang = 'en'
     Title = "OpenThinRDP hardware $dash drivers, requirements, thin clients that run it"
     Desc = 'Hardware for OpenThinRDP: any 64-bit x86 PC or thin client, UEFI or legacy BIOS, with the complete Debian 13 kernel and firmware. Tested devices, used thin clients that meet the requirements (Dell Wyse, HP t-series, Fujitsu Futro), firmware settings.' }
  @{ Doc = 'docs/udp.md'; Url = 'udp.html'; Lang = 'en'
     Title = "RDP over UDP on Linux $dash the FreeRDP UDP transport in OpenThinRDP"
     Desc = 'RDP over UDP on Linux with FreeRDP: the UDP transport (MS-RDPEUDP, pull request 13608) built and shipped by OpenThinRDP, what travels over UDP, the fixes we found and the measurements with packet loss against TCP.' }
  @{ Doc = 'docs/guides/replace-dell-thinos.md'; Url = 'replace-dell-thinos.html'; Lang = 'en'
     Title = "Replacing Dell ThinOS with OpenThinRDP $dash Wyse and OptiPlex thin clients"
     Desc = 'How to replace Dell ThinOS on Dell OptiPlex Thin Clients and Wyse thin clients with OpenThinRDP for Windows Remote Desktop: settings to copy, firmware settings, trying it live, installing, managing many devices without Wyse Management Suite.' }
  @{ Doc = 'docs/guides/old-pc-thin-client.md'; Url = 'old-pc-thin-client.html'; Lang = 'en'
     Title = "Turn an old PC into a thin client for Windows Remote Desktop $dash OpenThinRDP"
     Desc = 'Turn an old office PC or a used thin client into a free Remote Desktop thin client for a Windows PC, RDS or VDI: requirements, step by step from a USB stick, power schedule, USB, 802.1X, and when it is not the right choice.' }
)
$pages = @{}; foreach ($p in $site_pages) { $pages[$p.Doc] = $p.Url }
# the documents an AI assistant should read whole, in llms-full.txt, in this order
$fullDocs = 'README.md', 'docs/faq.md', 'docs/alternatives.md', 'docs/hardware.md', 'docs/status.md', 'docs/manager.md',
  'docs/guides/replace-dell-thinos.md', 'docs/guides/old-pc-thin-client.md', 'docs/configuration.md', 'docs/management.md',
  'docs/udp.md', 'docs/security.md'
# the texts of the page around the document
$ui = @{
  en = @{ Download = "Download $ver"; Manager = 'Manager'; Hardware = 'Hardware'; Compare = 'Compare'; Faq = 'FAQ'; FaqUrl = 'faq.html'
          Other = 'Italiano'; Footer = 'This page is {0} as published on <a href="https://github.com/{1}">GitHub</a>, where the documentation, the releases and the discussions are.' }
  it = @{ Download = "Scarica $ver"; Manager = 'Gestore'; Hardware = 'Hardware'; Compare = 'Confronto'; Faq = 'Domande'; FaqUrl = 'it/faq.html'
          Other = 'English'; Footer = 'Questa pagina &#232; {0} come pubblicato su <a href="https://github.com/{1}">GitHub</a>, dove ci sono la documentazione, le release e le discussioni.' }
}

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

function Build-Page($p) {
  $t = $ui[$p.Lang]
  $file = if ($p.Url -eq '' -or $p.Url.EndsWith('/')) { $p.Url + 'index.html' } else { $p.Url }
  $md = Get-Doc $p.Doc
  $tmp = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($tmp, $md, $utf8)
  $body = (& $gh api markdown -f mode=gfm -f context=$repo -F "text=@$tmp") -join "`n"
  Remove-Item $tmp
  $doc = $p.Doc; $dir = if ($doc.Contains('/')) { $doc.Substring(0, $doc.LastIndexOf('/')) } else { '' }
  # relative links -> the page of the site when there is one, else the repository on GitHub (anchors inside stay)
  $body = [regex]::Replace($body, 'href="(?!https?:|#|mailto:)([^"#]*)(#[^"]*)?"', {
    param($m) $r = Resolve-RepoPath $dir $m.Groups[1].Value; $a = $m.Groups[2].Value
    if ($pages.ContainsKey($r)) { 'href="' + $site + $pages[$r] + $a + '"' } else { 'href="' + "$blob/$r$a" + '"' } })
  $body = [regex]::Replace($body, 'src="(?!https?:|data:)([^"]+)"', { param($m) 'src="' + "$raw/" + (Resolve-RepoPath $dir $m.Groups[1].Value) + '"' })
  # the API gives the headings no id (GitHub's own page adds them with a script): the same ids as on GitHub, so
  # that #anchors inside the page and from other pages work
  $seen = @{}
  $body = [regex]::Replace($body, '<h([1-6]) dir="auto">(.*?)</h\1>', {
    param($m) $s0 = [Net.WebUtility]::HtmlDecode(($m.Groups[2].Value -replace '<[^>]+>', '')).Trim().ToLowerInvariant()
    $s = (($s0 -replace '[^\p{L}\p{Nd}\s_-]', '') -replace '\s', '-')
    if ($seen.ContainsKey($s)) { $seen[$s]++; $s = "$s-$($seen[$s])" } else { $seen[$s] = 0 }
    "<h$($m.Groups[1].Value) id=`"$s`" dir=`"auto`">$($m.Groups[2].Value)</h$($m.Groups[1].Value)>" }, 'Singleline')
  $url = $site + $p.Url
  $alt = ''; $other = ''
  if ($p.ContainsKey('Alt') -and ($site_pages | Where-Object { $_.Url -eq $p.Alt -and $_.Doc -ne $p.Doc })) {
    $o = $site_pages | Where-Object { $_.Url -eq $p.Alt } | Select-Object -First 1
    $alt = "<link rel=`"alternate`" hreflang=`"$($p.Lang)`" href=`"$url`">`n<link rel=`"alternate`" hreflang=`"$($o.Lang)`" href=`"$site$($o.Url)`">"
    if ($p.Lang -eq 'en') { $alt += "`n<link rel=`"alternate`" hreflang=`"x-default`" href=`"$url`">" } else { $alt += "`n<link rel=`"alternate`" hreflang=`"x-default`" href=`"$site$($o.Url)`">" }
    $other = "<a href=`"$site$($o.Url)`" hreflang=`"$($o.Lang)`">$($t.Other)</a>"
  } elseif ($p.Lang -eq 'it') {
    $other = "<a href=`"$site`" hreflang=`"en`">$($t.Other)</a>"
  }
  $faqLd = if ($p.Faq) { "<script type=`"application/ld+json`">" + (Get-FaqJson $md) + "</script>" } else { '' }
  $footer = $t.Footer -f "<a href=`"$blob/$doc`">$doc</a>", $repo
  $homeUrl = if ($p.Lang -eq 'it') { "${site}it/" } else { $site }
  $html = @"
<!doctype html>
<html lang="$($p.Lang)">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$($p.Title)</title>
<meta name="description" content="$($p.Desc)">
<link rel="canonical" href="$url">
$alt
<link rel="icon" href="${site}img/icon.png">
<link rel="alternate" type="text/plain" href="${site}llms-full.txt" title="The documentation in one text file">
<meta property="og:type" content="website">
<meta property="og:site_name" content="OpenThinRDP">
<meta property="og:locale" content="$(if ($p.Lang -eq 'it') { 'it_IT' } else { 'en_US' })">
<meta property="og:title" content="$($p.Title)">
<meta property="og:description" content="$($p.Desc)">
<meta property="og:url" content="$url">
<meta property="og:image" content="${site}img/social.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.8.1/github-markdown.min.css">
<link rel="stylesheet" href="${site}style.css">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"SoftwareApplication","name":"OpenThinRDP","applicationCategory":"OperatingSystem",
 "operatingSystem":"Debian 13 (Linux)","softwareVersion":"$ver","license":"https://github.com/$repo/blob/main/LICENSE",
 "offers":{"@type":"Offer","price":"0","priceCurrency":"EUR"},"url":"$site",
 "downloadUrl":"https://github.com/$repo/releases/latest","codeRepository":"https://github.com/$repo"}
</script>
$faqLd
</head>
<body>
<header class="bar"><a class="home" href="$homeUrl"><img src="${site}img/icon.png" alt="" width="28" height="28"> OpenThinRDP</a>
<nav><a href="https://github.com/$repo/releases/latest">$($t.Download)</a><a href="${site}manager.html">$($t.Manager)</a><a href="${site}hardware.html">$($t.Hardware)</a><a href="${site}alternatives.html">$($t.Compare)</a><a href="$site$($t.FaqUrl)">$($t.Faq)</a><a href="https://github.com/$repo">GitHub</a>$other</nav></header>
<main class="markdown-body">
$body
</main>
<footer class="bar small">$footer</footer>
</body>
</html>
"@
  $path = Join-Path $here ($file -replace '/', '\')
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  [IO.File]::WriteAllText($path, $html, $utf8)
  "${file}: $doc, release $ver, $([math]::Round($html.Length/1KB)) KB"
}

foreach ($p in $site_pages) { Build-Page $p }

# llms-full.txt: the documents whole (llmstxt.org), for assistants that read one file instead of crawling
$full = "# OpenThinRDP: the documentation in one file`n`nSource: https://github.com/$repo (main), release $ver, built $today. Every section below is one file of the repository.`n"
foreach ($d in $fullDocs) { $full += "`n`n---`n`n<!-- $blob/$d -->`n`n" + (Get-Doc $d) }
[IO.File]::WriteAllText((Join-Path $here 'llms-full.txt'), $full, $utf8)
"llms-full.txt: $($fullDocs.Count) documents, $([math]::Round($full.Length/1KB)) KB"

# sitemap.xml: every page, today, with its other language
$urls = foreach ($p in $site_pages) {
  $pr = if ($p.Url -eq '' -or $p.Url -eq 'it/') { '1.0' } else { '0.8' }
  $x = ''; if ($p.ContainsKey('Alt')) { $o = $site_pages | Where-Object { $_.Url -eq $p.Alt } | Select-Object -First 1
    if ($o) { $x = "<xhtml:link rel=`"alternate`" hreflang=`"$($p.Lang)`" href=`"$site$($p.Url)`"/><xhtml:link rel=`"alternate`" hreflang=`"$($o.Lang)`" href=`"$site$($o.Url)`"/>" } }
  "  <url><loc>$site$($p.Url)</loc>$x<lastmod>$today</lastmod><priority>$pr</priority></url>"
}
$urls += "  <url><loc>${site}llms-full.txt</loc><lastmod>$today</lastmod><priority>0.3</priority></url>"
[IO.File]::WriteAllText((Join-Path $here 'sitemap.xml'), "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`" xmlns:xhtml=`"http://www.w3.org/1999/xhtml`">`n" + ($urls -join "`n") + "`n</urlset>`n", $utf8)
'sitemap.xml written'
