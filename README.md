# NextJS + NextJS + Keycloak with oauth2-proxy

This repository contains a example to show the use of [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) with [NestJS](https://github.com/nestjs/nest) API, [NextJS](https://github.com/vercel/next.js) frontend and [Keycloak](https://github.com/keycloak/keycloak) for authentication.

## Setup

### Prerequisites

The repository includes a [Nix Flake](https://nix.dev/concepts/flakes.html) for easy setup. Be sure to [enable flakes](https://nixos.wiki/wiki/Flakes) in your Nix installation.

If you do not have Nix installed, run the following command for the complete setup using the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer):

```bash
curl  --proto  '=https'  --tlsv1.2  -sSf  -L  https://install.determinate.systems/nix | sh  -s  --  install
```

### Recommendations

[direnv](https://direnv.net) configuration is also included in the repository allowing automatic setup of environment
whenever a shell is started in the project's directory.

- `direnv` can be installed using [brew](https://formulae.brew.sh/formula/direnv#default) on MacOS.
  For other systems use the [relevant package](https://direnv.net/docs/installation.html#from-system-packages).:

  ```bash
  brew install direnv
  ```

- Make sure `direnv` is [hooked into your shell](https://direnv.net/docs/hook.html).
  For zsh add the following line to `~/.zshrc`:

  ```bash
  eval "$(direnv hook zsh)"
  ```

- On VSCode, [direnv VSCode Extension](https://marketplace.visualstudio.com/items?itemName=mkhl.direnv) is recommended.
  It loads the environment at the workspace root level. Allowing VSCode features like the integrated terminal to have
  access to the shell environment **instantaneously**.

### Getting Started

Activating the shell environment for the first time will take some time. Use either one of the following methods to get started.

#### Activating Shell Environment

##### With direnv (recommended)

For security reasons `direnv` doesn't load the shell environment automatically. Clone this repository and run the following command to allow `direnv` to _trust_ the repository:

```bash
direnv allow .
```

This needs to be done only once. Now whenever a shell is opened in this repository `direnv` will automatically start the shell environment.

##### Without direnv:

Clone this repository and whenever you need to start _developing_ run the following command to start the nix dev-shell:

```bash
nix develop --impure .
```

#### Starting example

Once in the development environment run the following command to import the expected keycloak realm:

```bash
keycloak-import
```

- Start the required processes with [process-compose](https://github.com/F1bonacc1/process-compose):

```bash
devenv up
```

- Once all the processes are up and running, access the example at [localhost:4180](http://localhost:4180)
