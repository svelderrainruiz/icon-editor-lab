$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Import-ScriptFunctions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Alias('Path')][string]$ScriptPath,
        [string[]]$FunctionNames
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Script not found: $ScriptPath"
    }

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
    $funcFinder = {
        param($node)
        return $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }

    $functionAsts = $ast.FindAll($funcFinder, $true)
    if ($FunctionNames) {
        $nameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($fn in $FunctionNames) { $null = $nameSet.Add($fn) }
        $functionAsts = $functionAsts | Where-Object { $nameSet.Contains($_.Name) }
    }

    foreach ($funcAst in $functionAsts) {
        $funcText = $funcAst.Extent.Text
        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
        $funcText = [System.Text.RegularExpressions.Regex]::Replace($funcText, '^\s*\[CmdletBinding([^\]]*)\]\s*', '', $regexOptions)
        $funcText = [System.Text.RegularExpressions.Regex]::Replace($funcText, '^\s*if\s*\(\s*-not\s+\$PSCmdlet\.ShouldProcess[^\{]+\{\s*return\s*\}\s*', '', $regexOptions)
        $funcText = [System.Text.RegularExpressions.Regex]::Replace($funcText, '^function\s+([^\s({]+)', 'function global:$1', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        Invoke-Expression $funcText
    }

    return @($functionAsts | Select-Object -ExpandProperty Name)
}
