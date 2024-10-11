# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  config.vm.provision "shell", path: "bootstrap.sh"

  # Load Balancer Nodes
  LoadBalancerCount = 2

  (1..LoadBalancerCount).each do |i|

    config.vm.define "loadbalancer#{i}" do |lb|

      lb.vm.box               = "ubuntu/focal64"
      lb.vm.box_check_update  = false
      #lb.vm.box_version       = "20240823.0.1"
      lb.vm.hostname          = "loadbalancer#{i}.example.com"

      lb.vm.network "private_network", ip: "172.16.16.5#{i}"
      lb.vm.provision "shell", path: "bootstrap.sh"

lb.vm.provider :virtualbox do |v|
  v.name   = "loadbalancer#{i}"
  v.memory = 512
  v.cpus   = 1
end
end
end

# Kubernetes Master Nodes
MasterCount = 3

(1..MasterCount).each do |i|

config.vm.define "kmaster#{i}" do |masternode|

masternode.vm.box               = "ubuntu/focal64"
masternode.vm.box_check_update  = false
#masternode.vm.box_version       = "20240823.0.1"
masternode.vm.hostname          = "kmaster#{i}.example.com"

masternode.vm.network "private_network", ip: "172.16.16.10#{i}"
masternode.vm.provision "shell", path: "bootstrap.sh"

masternode.vm.provider :virtualbox do |v|
  v.name   = "kmaster#{i}"
  v.memory = 2048
  v.cpus   = 2
end
end
end

# Kubernetes Worker Nodes
WorkerCount = 2

(1..WorkerCount).each do |i|

config.vm.define "kworker#{i}" do |workernode|

workernode.vm.box               = "ubuntu/focal64"
workernode.vm.box_check_update  = false
#workernode.vm.box_version       = "20240823.0.1"
workernode.vm.hostname          = "kworker#{i}.example.com"

workernode.vm.network "private_network", ip: "172.16.16.20#{i}"
workernode.vm.provision "shell", path: "bootstrap.sh"

workernode.vm.provider :virtualbox do |v|
  v.name   = "kworker#{i}"
  v.memory = 2048
  v.cpus   = 2
end
end
end

end

