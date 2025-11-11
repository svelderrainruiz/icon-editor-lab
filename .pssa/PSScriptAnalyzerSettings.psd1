@{
    Severity = @('Error','Warning')
    Rules = @{
        PSUseDeclaredVarsMoreThanAssignments = $true
        PSAvoidUsingWriteHost = $true
        PSAvoidUsingEmptyCatchBlock = $true
        PSUseApprovedVerbs = $true
        PSAvoidUsingInvokeExpression = $true
        PSAvoidUsingPlainTextForPassword = $true
        PSReviewUnusedParameter = $true
        PSAvoidTrailingWhitespace = $true
        PSAvoidUsingPositionalParameters = $true
        PSAvoidUsingCmdletAliases = $true
        PSUseConsistentWhitespace = $true
        PSUseConsistentIndentation = $true
        PSUseBOMForUnicodeEncodedFile = $true
    }
}