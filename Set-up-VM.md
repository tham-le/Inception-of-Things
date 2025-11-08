# Create a headless Ubuntu Server VM (the "Host VM") that will run Vagrant, Docker, and K3d

## Prerequisites

* VirtualBox installed on your school computer.
* Ubuntu Server ISO downloaded (e.g., 22.04 LTS or 24.04 LTS).
* `setup_inception_host.sh` (optional, just to install all needed dependencies)

## Steps

### 1.  Create VM in VirtualBox (GUI)

* Open VirtualBox -> Click "New".
* * **Name:** `Inception_Host_VM`
* **Type:** `Linux`, **Version:** `Ubuntu (64-bit)`
* **Memory:** **Min 6GB** (8GB+ recommended).
* **Hard Disk:** Create new, VDI, Dynamically allocated, **Min 60GB** (80GB+ recommended).
*Click "Create".

### 2.  **Configure VM Settings (Before First Boot):**

#### **2a. Pre-configure the Host-Only Network (Crucial Step!)**

Before configuring the VM's settings, we must ensure the host-only network for SSH access does **not** conflict with the network required by the project (`192.168.56.x`). The default for this is 

1. In the main VirtualBox window, go to the top menu: **File -> Tools -> Network Manager**.
2. A "Host-only Networks" tab will appear. You will likely see an adapter named `vboxnet0`.
3. Select `vboxnet0` and click **Properties**.
4. **Change the IPv4 Address** from the default `192.168.56.1` to a non-conflicting address. A safe choice is **`192.168.57.1`**.
5. Ensure the **IPv4 Network Mask** is `255.255.255.0`.
6. Click the **DHCP Server** tab and **uncheck "Enable Server"**. This is not needed and it's cleaner to disable it.
7. Click **Apply**. Now the `192.168.56.x` range is free for Vagrant to use.

#### **2b. Configure VM Settings (Before First Boot):**

*Select `Inception_Host_VM` -> "Settings".

* **System > Processor:**

    * **CPUs: Min 2** (4 recommended).
    * **Crucial: Enable Nested VT-x/AMD-V.**
* **Storage:**
    *Select "Empty" CD/DVD drive.
    *Click CD icon -> "Choose a disk file..." -> Select your Ubuntu Server ISO.
* **Network:**
    * **Adapter 1:** `NAT` (for internet).
    * **Adapter 2:** `Host-only Adapter` (e.g., `vboxnet0`) (for SSH from school PC). This adapter now uses the safe `192.168.57.x` range.
* **Shared Folders (Optional but Recommended):**
    *"+" -> **Folder Path:** Your project directory on school PC.
    * **Folder Name:** `project_files`.
    *Check "Auto-mount" & "Make Permanent".
*Click "OK".

### 3.  **Install Ubuntu Server:**

*Start `Inception_Host_VM`.
*Follow on-screen prompts for Ubuntu Server installation.
* **Language, Keyboard:** Your preference.
* **Installer Type:** Standard server (or "minimized" if offered).
* **Network:** Should auto-configure.
* **Storage:** Use entire virtual disk.
* **Profile Setup:** Create your user (e.g., `your_user`, password `your_password`).
* **SSH Setup: IMPORTANT - Select "Install OpenSSH server".**
* **Featured Server Snaps:** Skip all (you'll install tools manually/scripted).
*Wait for install, then reboot (remove ISO when prompted).

### 4.  **Post-Installation & Tool Setup (Inside Host VM via SSH):**

* **Login to Host VM:**
    *From VirtualBox console, or find its IP on the Host-only network (`ip a`) and SSH from your school computer: `ssh your_user@host_vm_host_only_ip`.
* **Update & Install Guest Additions (for Shared Folders):**
        ```bash
        sudo apt update && sudo apt full-upgrade -y
        sudo apt install -y virtualbox-guest-utils linux-headers-$(uname -r) dkms
        sudo usermod -aG vboxsf your_user # Add user to vboxsf group
        # sudo reboot # A reboot might be needed for guest additions/group changes to fully apply
        ```
    *er reboot, log back in via SSH.*
* **Access Project Files (Shared Folder):**
    *It should be mounted under `/media/sf_project_files/` (or the name you gave it). If not, manually mount:
            ```bash
            # sudo mkdir /mnt/project_files # If needed
            # sudo mount -t vboxsf project_files /mnt/project_files
            ```
* **Run Setup Script:**
    *Navigate to where `setup_inception_host.sh` is (e.g., `/media/sf_project_files/setup_inception_host.sh`).
    *Make it executable: `chmod +x /path/to/setup_inception_host.sh`
    *Execute it: `sudo bash /path/to/setup_inception_host.sh`
    *This script installs Vagrant, Docker, VirtualBox (for inner VMs), kubectl, k3d.
* **Verify Nested Virtualization:**
        ```bash
        kvm-ok
        ```
    *Output should be: `INFO: KVM acceleration can be used`. If not, re-check "Enable Nested VT-x/AMD-V" in VirtualBox settings for `Inception_Host_VM` (VM must be powered off to change).

### 5.  **Final Check & Logout/Login (for group changes):**
*The `setup_inception_host.sh` adds `your_user` (or `vagrant` if script used that) to `docker` and `vboxusers` groups. For these to take effect in your current SSH session, you might need to:
    *Exit SSH session and log back in.
    *Or run `newgrp docker` and `newgrp vboxusers` (this starts new sub-shells with the group).
*Test: `docker ps` (should run without sudo), `vagrant --version`.