# Writes to Carlos's Notebook > Notes (Ashenwake storyboard).
# Desktop OneNote COM. Notebook: Documents/Carlos's Notebook

param(
	[string]$AppendBuildNote = "",
	[string]$ReplaceInPage = "",
	[string]$Old = "",
	[string]$New = "",
	[string]$WritePage = "",
	[string]$PageText = ""
)

$ErrorActionPreference = "Stop"
$NotebookHint = "Carlos's Notebook"
$SectionName = "Notes"
$BuildPageName = "Build notes"

function Get-OneNoteApp {
	return New-Object -ComObject OneNote.Application
}

function Get-NotesSectionId([object]$onenote) {
	$xml = $null
	$onenote.GetHierarchy("", 4, [ref]$xml)
	$doc = [xml]$xml
	foreach ($nb in @($doc.Notebooks.Notebook)) {
		if ($nb.name -ne $NotebookHint) { continue }
		foreach ($sec in @($nb.Section)) {
			if ($sec -ne $null -and $sec.name -eq $SectionName) {
				return $sec.ID
			}
		}
	}
	throw "OneNote section '$SectionName' in '$NotebookHint' was not found."
}

function Get-PageIdByName([object]$onenote, [string]$sectionId, [string]$pageName) {
	$xml = $null
	$onenote.GetHierarchy($sectionId, 4, [ref]$xml)
	$doc = [xml]$xml
	foreach ($p in @($doc.Section.Page)) {
		if ($p -ne $null -and $p.name -eq $pageName) {
			return $p.ID
		}
	}
	return $null
}

function Get-PageXml([object]$onenote, [string]$pageId) {
	$xml = $null
	$onenote.GetPageContent($pageId, [ref]$xml, 7)
	return [string]$xml
}

function Set-PageXml([object]$onenote, [string]$xml) {
	$clean = $xml -replace ' selected="(partial|all)"', ""
	$onenote.UpdatePageContent($clean)
}

function Ensure-BuildPage([object]$onenote, [string]$sectionId) {
	$id = Get-PageIdByName $onenote $sectionId $BuildPageName
	if (-not [string]::IsNullOrEmpty($id)) {
		return $id
	}
	$newId = ""
	$onenote.CreateNewPage($sectionId, [ref]$newId)
	$xml = @"
<?xml version="1.0"?>
<one:Page xmlns:one="http://schemas.microsoft.com/office/onenote/2013/onenote" ID="$newId">
  <one:Title>
    <one:OE><one:T><![CDATA[$BuildPageName]]></one:T></one:OE>
  </one:Title>
  <one:Outline>
    <one:Position x="36.0" y="86.4" z="0"/>
    <one:Size width="540.0" height="220.0"/>
    <one:OEChildren>
      <one:OE><one:T><![CDATA[Implementation notes from Cursor. Design lists stay on the other pages; this page is what shipped.]]></one:T></one:OE>
      <one:OE><one:T><![CDATA[]]></one:T></one:OE>
    </one:OEChildren>
  </one:Outline>
</one:Page>
"@
	Set-PageXml $onenote $xml
	return $newId
}

function Add-BuildNote([object]$onenote, [string]$sectionId, [string]$text) {
	$pageId = Ensure-BuildPage $onenote $sectionId
	$xml = Get-PageXml $onenote $pageId
	$stamp = Get-Date -Format "yyyy-MM-dd"
	$line = "$stamp - $text"
	$close = $xml.LastIndexOf("</one:OEChildren>")
	if ($close -lt 0) {
		throw "Build notes page has no outline to append to."
	}
	$insert = '      <one:OE><one:T><![CDATA[' + $line + ']]></one:T></one:OE>' + [Environment]::NewLine + '      <one:OE><one:T><![CDATA[]]></one:T></one:OE>' + [Environment]::NewLine + '    '
	$xml = $xml.Substring(0, $close) + $insert + $xml.Substring($close)
	Set-PageXml $onenote $xml
}

function Replace-PageText([object]$onenote, [string]$sectionId, [string]$pageName, [string]$oldText, [string]$newText) {
	$pageId = Get-PageIdByName $onenote $sectionId $pageName
	if ([string]::IsNullOrEmpty($pageId)) {
		throw "OneNote page '$pageName' was not found."
	}
	$xml = Get-PageXml $onenote $pageId
	if ($xml.IndexOf($oldText) -lt 0) {
		Write-Output "SKIP $pageName (text not found)"
		return
	}
	$xml = $xml.Replace($oldText, $newText)
	Set-PageXml $onenote $xml
	Write-Output "UPDATED $pageName"
}

function Write-FullPage([object]$onenote, [string]$sectionId, [string]$pageName, [string]$text) {
	$pageId = Get-PageIdByName $onenote $sectionId $pageName
	if ([string]::IsNullOrEmpty($pageId)) {
		$onenote.CreateNewPage($sectionId, [ref]$pageId)
	}
	$lines = $text -split "`r?`n"
	$oes = ""
	foreach ($line in $lines) {
		$oes += '      <one:OE><one:T><![CDATA[' + $line + ']]></one:T></one:OE>' + [Environment]::NewLine
	}
	$xml = @"
<?xml version="1.0"?>
<one:Page xmlns:one="http://schemas.microsoft.com/office/onenote/2013/onenote" ID="$pageId">
  <one:Title>
    <one:OE><one:T><![CDATA[$pageName]]></one:T></one:OE>
  </one:Title>
  <one:Outline>
    <one:Position x="36.0" y="86.4" z="0"/>
    <one:Size width="620.0" height="720.0"/>
    <one:OEChildren>
$oes    </one:OEChildren>
  </one:Outline>
</one:Page>
"@
	Set-PageXml $onenote $xml
	Write-Output "WROTE $pageName"
}

$onenote = Get-OneNoteApp
$sectionId = Get-NotesSectionId $onenote

if ($WritePage -and $PageText) {
	Write-FullPage $onenote $sectionId $WritePage $PageText
	return
}

if ($ReplaceInPage -and $Old) {
	Replace-PageText $onenote $sectionId $ReplaceInPage $Old $New
	return
}

if ($AppendBuildNote) {
	Add-BuildNote $onenote $sectionId $AppendBuildNote
	Write-Output "APPENDED Build notes"
	return
}

$patches = @(
	@{ Page = "Status Effects"; Old = "less than 3 seconds"; New = "less than 1.5 seconds" },
	@{ Page = "Status Effects"; Old = "they will each provide a specific buff, I will work on this later."; New = "10s ally buff is in: Altered Fire, Altered Ice, Altered Lightning, Shadow Pact. Buff follows the second infusion if it is offensive, otherwise the first offensive infusion." },
	@{ Page = "Spell Augmentations"; Old = "20% CD reduction "; New = "Readiness - 20% CD reduction " },
	@{ Page = "Spell Augmentations"; Old = "20% increase range"; New = "Reach - 20% increase range" },
	@{ Page = "Spell Augmentations"; Old = "20% cost mana reduction"; New = "Efficiency - 20% cost mana reduction" },
	@{ Page = "Spell Augmentations"; Old = "20% increase cast speed"; New = "Haste - 20% increase cast speed" },
	@{ Page = "Spell Augmentations"; Old = "Spell echo (launches right after base projectiles) that deals 80% reduced damage"; New = "Echo - Spell echo (launches right after base projectiles) that deals 80% reduced damage" },
	@{ Page = "Spell Augmentations"; Old = "20% increase Spell area"; New = "Widen - 20% increase Spell area" },
	@{ Page = "Spell Augmentations"; Old = "100% increased crit chance"; New = "Precision - 100% increased crit chance" },
	@{ Page = "Spell Augmentations"; Old = "Crit damage increased to 250%"; New = "Lethality - Crit damage increased to 250%" },
	@{ Page = "Spell Augmentations"; Old = "Spell has no cast time, but 25% longer CD"; New = "Snap Cast - Spell has no cast time, but 25% longer CD" },
	@{ Page = "Spell Augmentations"; Old = "Spell can be recast (3 second window with no cast time), reduced damage of 30%, increased CD of 20%"; New = "Encore - Spell can be recast (3 second window with no cast time), reduced damage of 30%, increased CD of 20%" },
	@{ Page = "Spell Augmentations"; Old = "Can move while casting/channeling"; New = "Stride - Can move while casting/channeling" },
	@{ Page = "Spell Infusions"; Old = "ALTERED INFUSIONS:"; New = "ALTERED INFUSIONS (ally buffs from the Alteration augment, 10s):" },
	@{ Page = "Spell Infusions"; Old = "Nature - medium heal decrease - rejuvenation effect  - large CD decrease"; New = "Nature - medium heal decrease - rejuvenation effect  - large CD decrease. Can be cast on a teammate." },
	@{ Page = "Spell Infusions"; Old = "Divine - small heal increase - Holy blessing effect - no CD change"; New = "Divine - small heal increase - Holy blessing effect - no CD change. Can be cast on a teammate." },
	@{ Page = "Spell Infusions"; Old = "Protection - medium shield added as % of base damage - shield - medium CD increase"; New = "Protection - medium shield added as % of base damage - shield - medium CD increase. Can be cast on a teammate." },
	@{ Page = "Spell crafting"; Old = "You'd start with the base, then add up to 2 infusions, and 3 augments. "; New = "You'd start with the base, then add up to 2 infusions, and 3 augments. Beneficial infusions (Nature, Divine, Protection) can target a teammate. Offensive infusions can too if the spell has Alteration." }
)

foreach ($p in $patches) {
	Replace-PageText $onenote $sectionId $p.Page $p.Old $p.New
}

Add-BuildNote $onenote $sectionId "Workshop lobby is two columns so Play stays on screen. Alteration is an augment (not an infusion). Ally targeting plus Fire/Ice/Lightning/Shadow buffs are in. Training arena has an Ally Dummy on the left. Shock chain per-target ICD is 1.5s."
Write-Output "DONE"
