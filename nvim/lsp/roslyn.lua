return {
  capabilities = {
    workspace = {
      -- Disable file watchers. On macOS, closing FSEvents handles is slow (~4s)
      -- which makes quitting nvim hang when roslyn registers many watchers.
      didChangeWatchedFiles = { dynamicRegistration = false },
    },
  },
}
