# How to do it

## GIT

### SSH Keys

- generate a new key `ssh-keygen -t ed25519 -C "justin.lazarus@gmail.com"`
- start ssh-agent `eval "$(ssh-agent -s)"`
- add private key to agent `ssh-add ~/.ssh/id_ed25519`
- copy the public key to clipboard `cat ~/.ssh/id_ed25519.pub`
- paste the public key to github in profile/settings/access/keys

## LSP

### csharp-ls

- don't use omnisharp, that shit is old
- dotnet tool install --global csharp-ls

### omnisharp

- this thing works too, actually some better features than csharp-ls but harder to config
- use mason to get the stupid binary
- gets stored in `./local/share/nvim/mason/bin`
- i just added this dir to path
- once omnisharp is on the path, config like this:

```lua
require('lspconfig').omnisharp.setup({
  cmd = { "omnisharp", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) }
});
```
