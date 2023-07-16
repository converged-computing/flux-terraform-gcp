# Flux Terraform GCP

Terraform module to create Google Cloud images for Flux Framework HashiCorp Packer and AWS CodeBuild.
We are mirroring functionality from [GoogleCloudPlatform/scientific-computing-examples](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/openmpi/fluxfw-gcp), however we have refactored the entire
thing to only use one base image, and have all configuration done via a start boot script.
Thank you Google, we love you!

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
Note that we are currently advocating for using the single bursted image:

```bash
export GOOGLE_PROJECT=myproject
cd ./build-images/bursted
```
```bash
$ make
```

### Deploy with Terraform

You can build images under [build-images](build-images) and then use the modules
provided in [burst](burst). An example is provided in [examples/basic](examples/basic)
and you can see the [flux-burst-compute-engine](https://github.com/converged-computing/flux-burst-compute-engine).

## License

HPCIC DevTools is distributed under the terms of the MIT license.
All new contributions must be made under this license.

See [LICENSE](https://github.com/converged-computing/cloud-select/blob/main/LICENSE),
[COPYRIGHT](https://github.com/converged-computing/cloud-select/blob/main/COPYRIGHT), and
[NOTICE](https://github.com/converged-computing/cloud-select/blob/main/NOTICE) for details.

SPDX-License-Identifier: (MIT)

LLNL-CODE- 842614
