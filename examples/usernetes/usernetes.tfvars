make# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

manager_machine_type = "e2-standard-8"
manager_name_prefix  = "gffw"
manager_scopes       = ["cloud-platform"]
login_family         = "flux-usernetes-login-x86-64"
compute_family       = "flux-usernetes-compute-x86-64"
manager_family       = "flux-usernetes-manager-x86-64"
enable_os_login      = "TRUE"

login_node_specs = [
  {
    name_prefix     = "gffw-login"
    machine_arch    = "x86-64"
    machine_type    = "e2-standard-4"
    instances       = 1
    properties      = []
    boot_script     = "scripts/boot_script.sh"
    enable_os_login = "TRUE"
  },
]
login_scopes = ["cloud-platform"]

compute_node_specs = [
  {
    name_prefix     = "gffw-compute-a"
    machine_arch    = "x86-64"
    machine_type    = "c2-standard-16"
    enable_os_login = "TRUE"
    gpu_type        = null
    gpu_count       = 0
    compact         = false

    # This must be at least 2 for this experimetal setup
    instances   = 2
    properties  = []
    boot_script = "scripts/boot_script.sh"
  },
]
compute_scopes = ["cloud-platform"]
