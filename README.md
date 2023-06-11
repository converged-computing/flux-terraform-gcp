# Flux Terraform GCP

Terraform module to create Google Cloud images for Flux Framework HashiCorp Packer and AWS CodeBuild.
We are mirroring functionality from [GoogleCloudPlatform/scientific-computing-examples](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/openmpi/fluxfw-gcp). Thank you Google, we love you!

## Usage

### Create Google Service Accounts

Create default application credentials (just once):

```bash
$ gcloud auth application-default login
```
this is for packer to find and use.


### Build Images with Packer

Let's first go into [build-images](build-images) to use packer to build our images.
You'll need to first [install packer](https://developer.hashicorp.com/packer/downloads)
You can use the Makefile there to build all (or a select set of) images.

```bash
export GOOGLE_PROJECT=myproject
cd ./build-images/basic
```
```bash
$ make
# or
$ make compute
$ make login
$ make manager
```

If you are using the terraform recipes from [Google Cloud]() they still require an
arm image, so you'll need to build that:

```bash
$ make arm
```

Note that you can run these in separate terminals so they run at once and go
faster. We primarily use the defaults in the *.pkr.hcl files, which can
be changed directly or over-ridden in the Makefile with `-var name=value`.
A nicer design would be to have one common node built for all purposes,
but for now I'm mimicking the design [here](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/main/fluxfw-gcp/img).

#### Advanced

This isn't added, but there is a snippet we can add to [enable GPUs](build-images/config_gpus.txt) if interested.
I'd also like to refactor to build one image, or get logic from shared scripts to reduce redundancy, but this isn't a hill I need
to die on right now! XD

### Deploy with Terraform

Once you have images, choose a directory under [examples](examples) to deploy from:

```bash
$ cd examples/basic
```

I find it's easiest to export my Google project in the environment for any terraform configs
that mysteriously need it.

```bash
export GOOGLE_PROJECT=$(gcloud config get-value core/project)
```

For any example, edit the variables in the *.tfvars file. You should then init, fmt, validate, and then deploy:

```bash
$ make init
$ make fmt
$ make validate
$ make deploy
```

And they all can be run with `make`:

```bash
$ make
```

And when you are done:

```bash
$ make destroy
```

## License

HPCIC DevTools is distributed under the terms of the MIT license.
All new contributions must be made under this license.

See [LICENSE](https://github.com/converged-computing/cloud-select/blob/main/LICENSE),
[COPYRIGHT](https://github.com/converged-computing/cloud-select/blob/main/COPYRIGHT), and
[NOTICE](https://github.com/converged-computing/cloud-select/blob/main/NOTICE) for details.

SPDX-License-Identifier: (MIT)

LLNL-CODE- 842614
