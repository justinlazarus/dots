-- YAML Language Server configuration
-- Provides intelligent editing support for YAML files including:
-- - Schema validation and autocompletion
-- - Hover documentation
-- - Formatting and error detection
-- - Support for Kubernetes, Docker Compose, GitHub Actions, and more

return {
  cmd = { 'yaml-language-server', '--stdio' },
  filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab' },
  root_markers = {
    '.git',
    'docker-compose.yml',
    'docker-compose.yaml',
    '.github',
    '.gitlab-ci.yml',
  },
  settings = {
    yaml = {
      schemaStore = {
        -- Enable built-in schemaStore support
        enable = true,
        -- Automatically pull available schemas from store
        url = 'https://www.schemastore.org/api/json/catalog.json',
      },
      schemas = {
        -- Common schemas for popular YAML formats
        ['https://json.schemastore.org/github-workflow.json'] = '/.github/workflows/*',
        ['https://json.schemastore.org/github-action.json'] = '/action.{yml,yaml}',
        ['https://json.schemastore.org/ansible-stable-2.9.json'] = '/roles/tasks/*.{yml,yaml}',
        ['https://json.schemastore.org/prettierrc.json'] = '/.prettierrc.{yml,yaml}',
        ['https://json.schemastore.org/stylelintrc.json'] = '/.stylelintrc.{yml,yaml}',
        ['https://json.schemastore.org/circleciconfig.json'] = '/.circleci/**/*.{yml,yaml}',
        ['https://json.schemastore.org/docker-compose.json'] = '/docker-compose*.{yml,yaml}',
        ['https://json.schemastore.org/gitlab-ci.json'] = '/.gitlab-ci.{yml,yaml}',
        ['kubernetes'] = '/**/*.{yml,yaml}',
      },
      format = {
        enable = true,
        singleQuote = false,
        bracketSpacing = true,
      },
      validate = true,
      completion = true,
      hover = true,
      -- Disable default yamllint (we'll use prettier or yamlfmt instead)
      customTags = {
        '!reference sequence',
        '!Ref',
        '!Condition',
        '!Equals sequence',
        '!GetAtt',
        '!GetAZs',
        '!ImportValue',
        '!Join sequence',
        '!Select sequence',
        '!Split sequence',
        '!Sub sequence',
        '!Sub',
      },
    },
  },
}