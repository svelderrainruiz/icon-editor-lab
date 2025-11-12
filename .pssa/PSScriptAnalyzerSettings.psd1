@{
    Severity = @('Error','Warning')
    IncludeRules = @(
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingEmptyCatchBlock',
        'PSUseApprovedVerbs',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSReviewUnusedParameter',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingCmdletAliases',
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation',
        'PSUseBOMForUnicodeEncodedFile'
    )
}
