# mac-dotfiles

My macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
One script sets up a new machine. Every config lives in this repo, and your home folder only holds symlinks to it.

## What's in here

| Package     | Tool                                                    | Links to                                 |
| ----------- | ------------------------------------------------------- | ---------------------------------------- |
| `zsh`       | zsh + oh-my-zsh + Powerlevel10k                         | `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh` |
| `tmux`      | tmux (prefix `Ctrl-s`, nord theme)                      | `~/.tmux.conf`                           |
| `nvim`      | Neovim ([LazyVim](https://lazyvim.org))                 | `~/.config/nvim/`                        |
| `ghostty`   | Ghostty terminal + Catppuccin Midnight                  | `~/.config/ghostty/`                     |
| `aerospace` | AeroSpace tiling window manager                         | `~/.aerospace.toml`                      |
| `rex`       | Rex terminal (Superlogical) + Claude Code auto-resume   | `~/.config/rex/`                         |
| `zed`       | Zed editor                                              | `~/.config/zed/settings.json`            |
| `git`       | git (name/email stay in untracked `~/.gitconfig.local`) | `~/.gitconfig`, `~/.gitignore_global`    |
| `fastfetch` | fastfetch                                               | `~/.config/fastfetch/`                   |

Other files:

- `Brewfile` lists every Homebrew formula, cask, font and app the setup uses.
- `install.sh` does the whole setup: dependencies, frameworks, backups and symlinks.

Neovim and Ghostty both use the same **Catppuccin Midnight** palette, a slightly darker Catppuccin Mocha.

## Setting up a new Mac

```bash
xcode-select --install                 # git + compilers (skip if already installed)
git clone https://github.com/Abstract-Dex/mac-dotfiles.git ~/mac-dotfiles
cd ~/mac-dotfiles
./install.sh
```

Then open a new terminal. That's it.

> **Pushing changes:** the HTTPS clone above can pull but not push, because GitHub doesn't accept passwords. Once the machine's SSH key is [added to GitHub](https://github.com/settings/keys), switch the remote to SSH:
> `git remote set-url origin git@github.com:Abstract-Dex/mac-dotfiles.git`

### What `install.sh` does

1. **Homebrew**: installs it if it's missing, then runs `brew bundle` against the `Brewfile`.
2. **zsh framework**: clones oh-my-zsh, Powerlevel10k and zsh-autosuggestions if they're missing.
3. **Backups**: any existing file or folder a link would replace is moved to `~/.dotfiles-backup/<timestamp>/`. Nothing is deleted.
4. **Links**: creates `~/.config`, then runs `stow` for each package.
5. **Ghostty fix**: moves aside `~/Library/Application Support/com.mitchellh.ghostty/config` if it exists. On macOS that file overrides `~/.config/ghostty`.

You can run it again at any time. Anything already linked is left alone.

```bash
./install.sh --dry-run        # show what would happen, change nothing
./install.sh nvim tmux        # only (re)link these packages
./install.sh --no-brew        # skip Homebrew (e.g. on Linux, or to save time)
./install.sh --help
```

### First launch

| Tool      | What happens the first time                                                          |
| --------- | ------------------------------------------------------------------------------------ |
| tmux      | Clones TPM, installs the plugins and reloads. Takes a few seconds.                   |
| Neovim    | LazyVim installs its plugins. Run `:Lazy restore` to match `lazy-lock.json` exactly. |
| zsh       | Powerlevel10k uses the committed `~/.p10k.zsh`. Run `p10k configure` to redo it.     |
| AeroSpace | Open it once and grant Accessibility permission (it starts at login after that).     |
| Ghostty   | Picks up`JetBrains Mono` + the `catppuccin-midnight` theme automatically.            |

### Linux

Everything except `aerospace` (macOS only) works on Linux too. Install `stow`, `git`, `zsh`, `tmux`, `neovim`, `fzf`, `zoxide`, `ripgrep` and `fd` with your package manager, then run:

```bash
./install.sh --no-brew zsh tmux nvim git fastfetch
```

## Day-to-day

**Editing a config.** Edit it where it normally lives, e.g. `nvim ~/.zshrc`. That file is a symlink, so you're editing the repo copy. Then commit:

```bash
cd ~/mac-dotfiles && git add -A && git commit -m "tweak zsh" && git push
```

**Pulling changes onto another machine.**

```bash
cd ~/mac-dotfiles && git pull && ./install.sh --no-brew
```

**Adding a new tool** (for example `lazygit`, whose config is at `~/.config/lazygit/config.yml`):

```bash
mkdir -p ~/mac-dotfiles/lazygit/.config
mv ~/.config/lazygit ~/mac-dotfiles/lazygit/.config/
```

Then add `lazygit` to `ALL_PACKAGES` in `install.sh` and run `./install.sh lazygit`.
A package's folder mirrors the paths under `$HOME`.

**Removing a package's links.** `stow -D -d ~/mac-dotfiles -t ~ <package>` removes the links and leaves the repo alone.

**Updating the Brewfile.** Add or remove lines by hand. To see what's missing on the current machine, run `brew bundle check --verbose --file=~/mac-dotfiles/Brewfile`.

## Rex sessions and Claude Code

Rex keeps its sessions on a server, separate from the app:

- **Quitting the Rex app** leaves the server running, so every pane, including Claude Code, keeps going. Reopen Rex and you're back where you were.
- **Restarting the Mac, updating Rex, or `rex server stop`** saves the sessions, and the next server start restores them: sessions, tabs, splits, labels and each pane's folder. Programs and scrollback don't come back; each pane opens a fresh shell.
- **Claude Code comes back on its own.** `~/.config/rex/claude-resume.zsh` notes which pane was running Claude and which conversation. When the restored pane's shell starts, it runs `claude --resume <id>` (or `claude --continue` if that conversation can't be found). Exiting Claude normally stops it coming back. `REX_CLAUDE_RESUME=0` turns this off, and `rex-claude-forget` clears the current pane.

The helper is loaded at the end of `.zshrc` with this line:

```zsh
[[ -r ~/.config/rex/claude-resume.zsh ]] && source ~/.config/rex/claude-resume.zsh
```

Don't use `rex server stop --discard` or `--restore=false` unless you want to throw the saved sessions away.

## Machine-specific settings (not tracked)

Some things shouldn't go in a public repo: your git identity, secrets, work hosts, conda or other per-machine paths. Put them in these files, which are sourced or included automatically if they exist:

- `~/.zshrc.local`: sourced at the end of `.zshrc`.
- `~/.gitconfig.local`: included at the end of `.gitconfig`. **Your git name and email live here, not in the repo.** `install.sh` asks for them on first run. To create the file by hand:

  ```ini
  [user]
  	name = Your Name
  	email = you@example.com
  ```

  Tip: to keep your real address out of public commits too, use your GitHub no-reply email (_Settings → Emails_).

**Zed:** `settings.json` is tracked, so any SSH connections you add in Zed are written into this repo. Check `git diff` before you commit.

## How the links are laid out

Stow links whole folders where it can, so `~/.config/nvim` and `~/.config/ghostty` are each one symlink into the repo. New files you create there, such as a new Neovim plugin spec, land in the repo automatically.

Zed is the exception. It stores chats, prompts and other data next to its settings, so only `settings.json` is linked and that data stays out of git.

## Troubleshooting

- **`stow` reports a conflict.** Something not managed by stow is in the way. `./install.sh` backs these files up for you. If you run `stow` by hand, move the file first.
- **The prompt shows boxes instead of icons.** Set your terminal font to _MesloLGS Nerd Font_, which the Brewfile installs.
- **`brew bundle` fails for an app.** You probably installed that app outside Homebrew, and the warning is harmless. You can also delete the app and rerun the install to let Homebrew manage it.
