#
# Cookbook Name:: cookbook-openshift3
# Providers:: openshift_delete_host
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

use_inline_resources
provides :openshift_delete_host if defined? provides

def whyrun_supported?
  true
end

action :delete do
  %W(#{node['cookbook-openshift3']['openshift_service_type']}-node openvswitch #{node['cookbook-openshift3']['openshift_service_type']}-master #{node['cookbook-openshift3']['openshift_service_type']}-master-api #{node['cookbook-openshift3']['openshift_service_type']}-master-api-controllers etcd).each do |remove_service|
    service remove_service do
      action [:stop, :disable]
      ignore_failure true
    end
  end

  Mixlib::ShellOut.new('systemctl reset-failed').run_command
  Mixlib::ShellOut.new('systemctl daemon-reload').run_command
  Mixlib::ShellOut.new('systemctl unmask firewalld').run_command

  %w(lbr0 vlinuxbr vovsbr).each do |interface|
    Mixlib::ShellOut.new("ip link del #{interface}").run_command
  end

  Mixlib::ShellOut.new("find /var/lib/#{node['cookbook-openshift3']['openshift_service_type']}/openshift.local.volumes -type d -exec umount {} \; 2>/dev/null || true").run_command

  %W(#{node['cookbook-openshift3']['openshift_service_type']} #{node['cookbook-openshift3']['openshift_service_type']}-master #{node['cookbook-openshift3']['openshift_service_type']}-node #{node['cookbook-openshift3']['openshift_service_type']}-sdn-ovs #{node['cookbook-openshift3']['openshift_service_type']}-clients cockpit-bridge cockpit-docker cockpit-shell cockpit-ws openvswitch tuned-profiles-#{node['cookbook-openshift3']['openshift_service_type']}-node etcd httpd).each do |remove_package|
    package remove_package do
      action :remove
      ignore_failure true
    end
  end
  new_resource.updated_by_last_action(true)

  %W(/etc/dnsmasq.d/origin-dns.conf /etc/dnsmasq.d/origin-upstream-dns.conf /etc/NetworkManager/dispatcher.d/99-origin-dns.sh /etc/#{node['cookbook-openshift3']['openshift_service_type']}  /etc/sysconfig/openvswitch /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-node /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-node-dep /etc/systemd/system/openvswitch.service /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-node-dep.service /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-node.service /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-node.service.wants /run/openshift-sdn /var/lib/origin/* /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-master /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-master-api /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers /etc/sysconfig/openvswitch /root/.kube /usr/share/openshift/examples /usr/share/openshift/hosted /usr/local/bin/openshift /usr/local/bin/oadm /usr/local/bin/oc /usr/local/bin/kubectl /etc/etcd/* /etc/httpd/* /var/lib/etcd/* /var/www/html/*).each do |file_to_remove|
    Mixlib::ShellOut.new("rm -rf #{file_to_remove}").run_command
  end

  reboot 'Uninstall require reboot' do
    action :request_reboot
    reason 'Need to reboot when the run completes successfully.'
    delay_mins 1
    only_if { node['cookbook-openshift3']['openshift_adhoc_reboot_node'] == true }
  end
end
