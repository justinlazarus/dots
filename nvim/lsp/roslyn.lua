return {
  settings = {
    background_analysis = {
      dotnet_analyzer_diagnostics_scope = 'fullSolution',
      dotnet_compiler_diagnostics_scope = 'fullSolution',
    },
    code_lens = {
      dotnet_enable_references_code_lens = true,
      dotnet_enable_tests_code_lens = true,
    },
    completion = {
      dotnet_show_completion_items_from_unimported_namespaces = true,
      dotnet_show_name_completion_suggestions = true,
    },
    inlay_hints = {
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types = true,
      csharp_enable_inlay_hints_for_types = true,
      dotnet_enable_inlay_hints_for_indexer_parameters = true,
      dotnet_enable_inlay_hints_for_literal_parameters = true,
      dotnet_enable_inlay_hints_for_parameters = true,
    },
    symbol_search = {
      dotnet_search_reference_assemblies = true,
    },
  },
}
