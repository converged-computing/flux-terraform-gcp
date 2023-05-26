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
cd ./build-images
```
```bash
$ make
# or
$ make compute
$ make login
$ make manager
```
Note that you can run these in separate terminals so they run at once and go
faster. We primarily use the defaults in the *.pkr.hcl files, which can
be changed directly or over-ridden in the Makefile with `-var name=value`.
A nicer design would be to have one common node built for all purposes,
but for now I'm mimicking the design [here](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/main/fluxfw-gcp/img).

### Deploy with Terraform

**under development** and not added yet

Once you have images, choose a directory under **examples** to deploy from:

```bash
$ cd examples/basic
```

For any example, edit the variables in the *.tfvars file. You should then init, fmt, validate, and then deploy (build)

```bash
$ make init
$ make fmt
$ make validate
$ make build
```

And they all can be run with `make`:

```bash
$ make
```
