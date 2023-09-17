# Flight Profile

Manage node provisioning.

## Overview

Flight Profile is an interactive node provisioning tool, providing an abstracted, command-line based system for the setup of nodes via Ansible or similar provisioning tools.

## Installation

### Manual installation

#### Prerequisites
Flight Profile is developed and tested with Ruby version 2.7.1 and bundler 2.1.4. Other versions may work but currently are not officially supported.

#### Steps

The following will install from source using Git. The master branch is the current development version and may not be appropriate for a production installation. Instead a tagged version should be checked out.

```bash
git clone https://github.com/openflighthpc/flight-profile.git
cd flight-profile
git checkout <tag>
bundle install --path=vendor
```

Flight Profile requires the presence of an adjacent `flight-profile-types` directory. The following will install that repository using Git.
```bash
cd /path/to/flight-profile/../
git clone https://github.com/openflighthpc/flight-profile-types.git
cd flight-profile-types
git checkout <tag>
```

This repository contains the cluster types that are used by Flight Profile.

## Configuration

To begin, run `bin/profile configure`. Here, you will set the cluster type to be used (present in `flight-profile-types`), as well as any required parameters specified in the metadata for that type.

These parameters must be set before you can run Flight Profile.

## Commands & Usage

Flight Profile provides a series of commands that covers the entire lifecycle of node provisioning. This chapter explains the usage of each command.

### Help

In addition to consulting this README documentation, Flight Profile also integrates a detailed usage guide, which can be accessed by running the `help` command.

```
bin/profile help
```

The above statement provides a description of all the available commands. For the guide of a specific command, such as `configure`, it can be accessed by running the following command:

```
bin/profile configure help  # raplace 'configure' with the actual command as needed
```

### Avail

This command provides a list of availabe cluster types, along with thier corresponding descriptions:

```
bin/profile avail
```

### Configure

The `configure` command could be the first command that needs to be run in the entire lifecycle. It allows the user to choose the cluster type to be applied and provides corresponding customization options.

```
bin/profile configure
```

By running this command, the desired cluster type will be firstly selected. After that, a set of questions will be asked to collect the required information for the cluster.

This command also pffers a range of options to meet user requirements. As mentioned before, details can be viewed directly in the toll by using the `help` command. Here is an example syntax using options:

```
bin/profile configure --show    # this --show option shows the current configuration details
```

### Identities

Since the cluster type is selected during the configuration stage, the available identities are also determined. Therefore, the `identities` command can be run to list the identities for the chosen cluster type.

```
bin/profile identities
```

This command also accept a cluster type as the parameter to show the identities of the specified type.

```
bin/profile identites openflight-slurm-multinode
```

For instance, by running the above command, a list of the identities available for a slurm multinode cluster, typically including 'login' and 'compute' identities, will be displayed on the console.

### Apply

After the configuration process is done, the cluster is ready for being applied. This can be accomplished using the `apply` command. The syntax of this command is given below:

```
bin/profile apply <node1>,<node2>,...,<noden> <identity>
```

In this statement, the <node> tags represent the hostname of the nodes, or their labels or gender parsed by [Flight Hunter](https://github.com/openflighthpc/flight-hunter).

After submitting this command, the apply process will run in the background and the command line won't be blocked, allowing the user to continue applying other nodes. These subsequently submitted nodes will be added to the queue.

Note that just like `configure`, this command also accepts a number of custom options. when applying to a set of nodes, you may use the `--remove-on-shutdown` option. When used, the nodes being applied to will be given a `systemd` unit that, when stopped (presumably, on system shutdown), attempts to communicate to the applier node that they have shut down and should be `remove`'d from Profile. The option requires:

- The `shared_secret_path` config option to be set
- `flight-profile-api` set up and running on the same system, using the same shared secret

### List & View

As explained in last section, all the apply processes will form a queue running in the background. Flight Profile offers two approaches, `list` and `view`, to query the progress.

The former, `list`, can be used to obtain a table summarizing the progress of each node. This way, a clear view can be achieved, showing which nodes have already completed, or failed, and which ones are waiting to be appled.

```
bin/profile list
```

While the latter, `view`, is helpful for viewing the detailed progress of a specific node:

```
bin/profile view <node>
```

# Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

# Copyright and License

Eclipse Public License 2.0, see [LICENSE.txt](LICENSE.txt) for details.

Copyright (C) 2022-present Alces Flight Ltd.

This program and the accompanying materials are made available under
the terms of the Eclipse Public License 2.0 which is available at
[https://www.eclipse.org/legal/epl-2.0](https://www.eclipse.org/legal/epl-2.0),
or alternative license terms made available by Alces Flight Ltd -
please direct inquiries about licensing to
[licensing@alces-flight.com](mailto:licensing@alces-flight.com).

Flight Profile is distributed in the hope that it will be
useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER
EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR
CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR
A PARTICULAR PURPOSE. See the [Eclipse Public License 2.0](https://opensource.org/licenses/EPL-2.0) for more
details.

