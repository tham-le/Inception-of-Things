# Part 1: K3s and Vagrant

For the first part we need to:

- Set up 2 virtual machines using Vagrant

  - - Server (yourloginS): K3s controller.
    - ServerWorker (yourloginSW): K3s agent.



We choosed Alpine as this is the second most [lightweight linux distro] (<https://en.wikipedia.org/wiki/Light-weight_Linux_distribution>). 

then I go to <https://portal.cloud.hashicorp.com/vagrant/discover/cloud-image/alpine-3.21> to find the lastest version of alpine (3.21).

The page show a minimal template for Vagrantfile. Let's use it. 