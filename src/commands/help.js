export function cmdHelp() {
  console.log(`dojo — install or start tutored coding-dojo plugins for Claude Code

USAGE
  dojo <command> [args]

COMMANDS
  run <name> [dir] [claude args]   Start a dojo right away (ephemeral, nothing installed).
                                   Runs in <dir> (created if given), offline jail on.
  install <name>                   Install a dojo persistently (native Claude Code plugin).
  uninstall <name>                 Remove an installed dojo.
  list                             List every dojo across all registries.
  update                           Pull the latest tool + dojos from every registry.
  new [topic]                      Author a new dojo with the dojo-forge generator.
  registry add <git-url> [name]    Add another registry (an org's dojos repo).
  registry list                    Show configured registries.
  registry remove <url|name>       Remove a registry.
  help                             Show this help.

EXAMPLES
  dojo list
  dojo run demonkey ./my-workshop
  dojo install c10k-dojo
  dojo registry add git@github.com:acme/dojos.git acme
`);
  return 0;
}
