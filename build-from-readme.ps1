# Builds https://openthinrdp.github.io/ from the documents published on GitHub, so the site is never a second copy
# of the documentation: the text rendered by GitHub itself, links pointing to the pages of the site or to GitHub.
# The pages are listed in $site_pages below. English only (decided 13/10; the Italian pages were removed on 20/10), because a
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
# the ISO: in the newest release that has one (not every release is built again as an ISO: an installed device
# updates itself), else the latest release
$iso = try { @((@(& $gh api "repos/$repo/releases?per_page=50") -join "`n" | ConvertFrom-Json) | Where-Object { @($_.assets | Where-Object { $_.name -like '*.iso' }).Count })[0].html_url } catch { $null }
if (-not $iso) { $iso = "https://github.com/$repo/releases/latest" }
$today = Get-Date -Format 'yyyy-MM-dd'
$dash = '&#8211;'   # PowerShell 5.1 reads this file as ANSI: no non-ASCII characters in it

# Doc = file of the repository; Url = its address on the site ('' = home, a folder ends with /); Alt = the same page in
# the other language; Faq = FAQPage structured data from its "### question" sections
$site_pages = @(
  @{ Doc = 'README.md'; Url = ''; Lang = 'en'
     Title = "OpenThinRDP $dash open source thin client OS with RDP over UDP for RDS and VDI"
     Desc = 'OpenThinRDP: free, open source thin client operating system for Microsoft Remote Desktop (RDS and VDI) and Windows VMs on Hyper-V, Proxmox, VMware or any cloud. Debian 13 with FreeRDP and the RDP UDP transport, a kiosk sign-in, central management from a shared folder, signed updates with pilot devices and rollback.' }
  @{ Doc = 'docs/guides/getting-started.md'; Url = 'getting-started.html'; Lang = 'en'
     Title = "Getting started with OpenThinRDP $dash from a USB stick to a managed thin client fleet"
     Desc = 'Step by step: try OpenThinRDP live with its hardware test, install it, set up the management folder and the Windows manager, and set up every new thin client with only a domain account.' }
  # the page that sells the manager: the page of its own project (Repo), its questions as FAQPage
  @{ Doc = 'README.md'; Repo = 'OpenThinRdp/openthinrdp-manager'; Url = 'manager.html'; Lang = 'en'; Faq = $true
     Title = "Free Hyper-V, Proxmox and Remote Desktop health check $dash OpenThinRDP Manager"
     Desc = 'Find what is broken in your Hyper-V cluster, Proxmox, vSphere, Remote Desktop, Citrix, Veeam and certificates before your users call. One free Windows app, no agent, no server: plain-English findings and repairs you confirm.' }
  @{ Doc = 'docs/manager.md'; Url = 'manager-guide.html'; Lang = 'en'
     Title = "OpenThinRDP Manager guide $dash the Health Center, certificates, platforms and the thin client fleet"
     Desc = 'The complete guide of the OpenThinRDP Manager: Home, the Health Center for Hyper-V, Proxmox, vSphere, RDS, Citrix, SQL and Veeam, certificates and the enterprise CA, updates of the thin clients, scheduled jobs, the vault and the command line.' }
  @{ Doc = 'docs/guides/hyper-v-rds-health-check.md'; Url = 'hyper-v-rds-health-check.html'; Lang = 'en'
     Title = "Free Hyper-V cluster and Remote Desktop health check $dash no agent, no server"
     Desc = 'A free health check for Hyper-V hosts, failover clusters and S2D, Remote Desktop Services brokers and session hosts, Active Directory, SQL AlwaysOn and VM backups: one window, no agent, no server, a repair you confirm for each problem.' }
  @{ Doc = 'docs/faq.md'; Url = 'faq.html'; Lang = 'en'; Faq = $true
     Title = "OpenThinRDP FAQ $dash hardware, drivers, RDP over UDP, Azure, PXE, 802.1X"
     Desc = 'Questions and answers about OpenThinRDP, the free thin client OS for Microsoft Remote Desktop: which hardware, drivers, RDP over UDP, RDS and VDI, Azure Virtual Desktop, management without a server, updates and rollback, PXE, 802.1X.' }
  @{ Doc = 'docs/alternatives.md'; Url = 'alternatives.html'; Lang = 'en'
     Title = 'OpenThinRDP compared with Linux Mint + Remmina, IGEL OS, Dell ThinOS, Stratodesk, ThinStation'
     Desc = 'A free alternative to IGEL OS, Dell ThinOS, Stratodesk NoTouch, ThinStation and openthinclient for Windows Remote Desktop, and why not just Linux Mint with Remmina: RDP over UDP, a locked kiosk, central management, signed updates with rollback.' }
  @{ Doc = 'docs/hardware.md'; Url = 'hardware.html'; Lang = 'en'
     Title = "OpenThinRDP hardware $dash drivers, requirements, thin clients that run it"
     Desc = 'Hardware for OpenThinRDP: any 64-bit x86 PC or thin client, UEFI or legacy BIOS, with the complete Debian 13 kernel and firmware. Tested devices, used thin clients that meet the requirements (Dell Wyse, HP t-series, Fujitsu Futro), firmware settings.' }
  @{ Doc = 'docs/maturity.md'; Url = 'maturity.html'; Lang = 'en'
     Title = "Is OpenThinRDP production ready? $dash security, tests, rollback, field data"
     Desc = 'Production readiness of OpenThinRDP area by area: security and signed updates, automated tests, tests on a production device (rollback in 30 s, an interrupted update that installs again by itself, network cut, zero-touch), field data and what is still missing.' }
  @{ Doc = 'docs/udp.md'; Url = 'udp.html'; Lang = 'en'
     Title = "RDP over UDP on Linux $dash the FreeRDP UDP transport in OpenThinRDP"
     Desc = 'RDP over UDP on Linux with FreeRDP: the UDP transport (MS-RDPEUDP, pull request 13608) built and shipped by OpenThinRDP, what travels over UDP, the fixes we found and the measurements with packet loss against TCP.' }
  @{ Doc = 'docs/guides/replace-dell-thinos.md'; Url = 'replace-dell-thinos.html'; Lang = 'en'
     Title = "Replacing Dell ThinOS with OpenThinRDP $dash Wyse and OptiPlex thin clients"
     Desc = 'How to replace Dell ThinOS on Dell OptiPlex Thin Clients and Wyse thin clients with OpenThinRDP for Windows Remote Desktop: settings to copy, firmware settings, trying it live, installing, managing many devices without Wyse Management Suite.' }
  @{ Doc = 'docs/guides/old-pc-thin-client.md'; Url = 'old-pc-thin-client.html'; Lang = 'en'
     Title = "Turn an old PC into a thin client for Windows Remote Desktop $dash OpenThinRDP"
     Desc = 'Turn an old office PC or a used thin client into a free Remote Desktop thin client for a Windows PC, RDS or VDI: requirements, step by step from a USB stick, power schedule, USB, 802.1X, and when it is not the right choice.' }
  @{ Doc = 'docs/guides/proxmox-vmware-thin-client.md'; Url = 'proxmox-vmware-thin-client.html'; Lang = 'en'
     Title = "Free thin client for Proxmox, VMware and Nutanix VMs $dash OpenThinRDP"
     Desc = 'A free thin client OS for Windows VMs on Proxmox VE, VMware vSphere/ESXi, Nutanix AHV, XCP-ng and KVM, and Linux desktops through xrdp: RDP over UDP, USB, webcams, a whole fleet managed from one window, no licence per device.' }
  @{ Doc = 'docs/privacy.md'; Url = 'privacy.html'; Lang = 'en'
     Title = "OpenThinRDP privacy $dash the anonymous counts, all of them, and how to switch them off"
     Desc = 'What OpenThinRDP and its manager send to the project: a few anonymous counts (version, model, processor, memory), never names, addresses or users. On GoatCounter, no cookies, no IP addresses. How to switch it off on one device, a whole site or the manager.' }
  @{ Doc = 'CHANGELOG.md'; Url = 'changelog.html'; Lang = 'en'
     Title = "OpenThinRDP changelog $dash what changed in every release"
     Desc = 'Every release of OpenThinRDP, newest first: new features, fixes, security updates and major updates of the thin client OS and of its Windows manager.' }
)
$pages = @{}; foreach ($p in $site_pages) { if (-not $p.ContainsKey('Repo')) { $pages[$p.Doc] = $p.Url } }
# the documents an AI assistant should read whole, in llms-full.txt, in this order
$fullDocs = 'README.md', 'docs/guides/getting-started.md', 'docs/faq.md', 'docs/alternatives.md', 'docs/hardware.md', 'docs/status.md', 'docs/manager.md',
  'docs/guides/replace-dell-thinos.md', 'docs/guides/old-pc-thin-client.md', 'docs/guides/proxmox-vmware-thin-client.md', 'docs/configuration.md', 'docs/management.md',
  'docs/udp.md', 'docs/security.md', 'docs/privacy.md', 'docs/maturity.md'
# the texts of the page around the document
$ui = @{
  en = @{ Download = "Download $ver"; Manager = 'Manager'; Hardware = 'Hardware'; Compare = 'Compare'; Faq = 'FAQ'; FaqUrl = 'faq.html'; Changelog = 'Changelog'
          Other = 'Italiano'; Footer = 'This page is {0} as published on <a href="https://github.com/{1}">GitHub</a>, where the documentation, the releases and the discussions are.' }
  it = @{ Download = "Scarica $ver"; Manager = 'Gestore'; Hardware = 'Hardware'; Compare = 'Confronto'; Faq = 'Domande'; FaqUrl = 'it/faq.html'; Changelog = 'Novit&#224;'
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
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${site}style.css">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"SoftwareApplication","name":"$(if ($p.ContainsKey('Repo')) { 'OpenThinRDP Manager' } else { 'OpenThinRDP' })","applicationCategory":"$(if ($p.ContainsKey('Repo')) { 'UtilitiesApplication' } else { 'OperatingSystem' })",
 "operatingSystem":"$(if ($p.ContainsKey('Repo')) { 'Windows' } else { 'Debian 13 (Linux)' })","softwareVersion":"$ver","license":"https://github.com/$repo/blob/main/$(if ($p.ContainsKey('Repo')) { 'LICENSE.md' } else { 'LICENSE' })",
 "offers":{"@type":"Offer","price":"0","priceCurrency":"EUR"},"url":"$site",
 "downloadUrl":"https://github.com/$repo/releases/latest","codeRepository":"https://github.com/$repo"}
</script>
$faqLd
</head>
<body>
<header class="bar"><a class="home" href="$homeUrl"><img src="${site}img/icon.png" alt="" width="30" height="30"> <span>OpenThin<b>RDP</b></span></a>
<nav><a href="https://github.com/$repo/releases/latest">$($t.Download)</a><a href="${site}manager.html">$($t.Manager)</a><a href="${site}hardware.html">$($t.Hardware)</a><a href="${site}alternatives.html">$($t.Compare)</a><a href="$site$($t.FaqUrl)">$($t.Faq)</a><a href="${site}changelog.html">$($t.Changelog)</a><a href="https://github.com/$repo">GitHub</a>$other</nav></header>
<main class="markdown-body">
$body
</main>
<footer class="bar small">$footer</footer>
<script data-goatcounter="https://ceschi-ops.goatcounter.com/count" async src="//gc.zgo.at/count.js"></script>
</body>
</html>
"@
  $path = Join-Path $here ($file -replace '/', '\')
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  [IO.File]::WriteAllText($path, $html, $utf8)
  "${file}: $doc, release $ver, $([math]::Round($html.Length/1KB)) KB"
}

foreach ($p in $site_pages) {
  # a page of another repository (the manager): its text, links, downloads and version from there
  if ($p.ContainsKey('Repo')) { $keep = $repo, $blob, $raw, $ver; $script:repo = $p.Repo; $script:blob = "https://github.com/$($p.Repo)/blob/main"; $script:raw = "https://raw.githubusercontent.com/$($p.Repo)/main"; $script:ver = (& $gh api "repos/$($p.Repo)/releases/latest" --jq .tag_name) -replace '^v', '' }
  Build-Page $p
  if ($p.ContainsKey('Repo')) { $script:repo, $script:blob, $script:raw, $script:ver = $keep }
}
# the home page is the designed landing (landing.html + landing.css), with the facts of the README; the README itself
# stays the source of every other page
$land = [IO.File]::ReadAllText((Join-Path $here 'landing.html')).Replace('{{SITE}}', $site).Replace('{{VER}}', $ver).Replace('{{ISO}}', $iso)
[IO.File]::WriteAllText((Join-Path $here 'index.html'), $land, $utf8); "index.html: landing, release $ver"

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
