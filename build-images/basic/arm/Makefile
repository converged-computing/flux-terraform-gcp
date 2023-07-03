.PHONY: all
all: init fmt validate build

.PHONY: init
init: 
	packer init .
	
.PHONY: fmt
fmt: 
	packer fmt .

.PHONY: validate
validate: 
	packer validate .
	
.PHONY: build
build: 
	# Rocky-8-EC2-Base-8.7-20230215.0.x86_64-d6577ceb-8ea8-4e0e-84c6-f098fc302e82
	# Note we are using defaults in arm.pkr.hcp
	packer build -var machine_architecture="arm64" -var project_id=${GOOGLE_PROJECT} arm.pkr.hcl
