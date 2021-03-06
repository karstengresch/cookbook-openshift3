#
# Cookbook Name:: cookbook-openshift3
# Recipe:: master_config_post
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

master_servers = node['cookbook-openshift3']['master_servers']
node_servers = node['cookbook-openshift3']['node_servers']

remote_file "#{Chef::Config[:file_cache_path]}/admin.kubeconfig" do
  source 'file:///etc/origin/master/admin.kubeconfig'
  mode '0644'
end

node['cookbook-openshift3']['openshift_common_service_accounts'].each do |serviceaccount|
  execute "Creation service account: \"#{serviceaccount['name']}\" ; Namespace: \"#{serviceaccount['namespace']}\"" do
    command 'oc create sa ${serviceaccount} -n ${namespace} --config=admin.kubeconfig'
    environment(
      'serviceaccount' => serviceaccount['name'],
      'namespace' => serviceaccount['namespace']
    )
    cwd Chef::Config[:file_cache_path]
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get sa #{serviceaccount['name']} -n #{serviceaccount['namespace']}"
  end

  next unless serviceaccount.key?('scc')

  execute "Add SCC to service account: \"#{serviceaccount['name']}\" ; Namespace: \"#{serviceaccount['namespace']}\"" do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} policy add-scc-to-user privileged system:serviceaccount:#{serviceaccount['namespace']}:#{serviceaccount['name']} --config=admin.kubeconfig"
    cwd Chef::Config[:file_cache_path]
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get scc/privileged -n default -o yaml | grep default:#{serviceaccount['name']}"
  end
end

execute 'Import Openshift Hosted Examples' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_hosted_base']} --recursive --config=admin.kubeconfig -n openshift || #{node['cookbook-openshift3']['openshift_common_client_binary']} replace -f #{node['cookbook-openshift3']['openshift_common_hosted_base']} --recursive --config=admin.kubeconfig -n openshift"
  cwd Chef::Config[:file_cache_path]
  ignore_failure true
end

execute 'Import Openshift db templates' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/db-templates --recursive --config=admin.kubeconfig -n openshift || #{node['cookbook-openshift3']['openshift_common_client_binary']} replace -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/db-templates --recursive --config=admin.kubeconfig -n openshift"
  cwd Chef::Config[:file_cache_path]
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_db_templates'] }
  ignore_failure true
end

execute 'Import Openshift Examples Base image-streams' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/image-streams/#{node['cookbook-openshift3']['openshift_base_images']} --recursive --config=admin.kubeconfig -n openshift || #{node['cookbook-openshift3']['openshift_common_client_binary']} replace -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/image-streams/#{node['cookbook-openshift3']['openshift_base_images']} --recursive --config=admin.kubeconfig -n openshift"
  cwd Chef::Config[:file_cache_path]
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_image-streams'] }
  ignore_failure true
end

execute 'Import Openshift Examples quickstart-templates' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/quickstart-templates --recursive --config=admin.kubeconfig -n openshift"
  cwd Chef::Config[:file_cache_path]
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_quickstart-templates'] }
  ignore_failure true
end

execute 'Import Openshift Examples xpaas-streams' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/xpaas-streams --recursive --config=admin.kubeconfig -n openshift"
  cwd Chef::Config[:file_cache_path]
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_xpaas-streams'] }
  ignore_failure true
end

execute 'Import Openshift Examples xpaas-templates' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/xpaas-templates --recursive --config=admin.kubeconfig -n openshift"
  cwd Chef::Config[:file_cache_path]
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_xpaas-templates'] }
  ignore_failure true
end

node_servers.each do |nodes|
  next if Mixlib::ShellOut.new("oc get node | egrep \"#{nodes['fqdn']}[[:space:]]\+Ready\"").run_command.error?
  execute "Set schedulability for Master node : #{nodes['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} manage-node #{nodes['fqdn']} --schedulable=${schedulability} --config=admin.kubeconfig"
    environment(
      'schedulability' => !nodes.key?(:schedulable) && master_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] } ? 'False' : nodes['schedulable'].to_s
    )
    cwd Chef::Config[:file_cache_path]
    only_if do
      master_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] }
    end
  end

  execute "Set schedulability for node : #{nodes['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} manage-node #{nodes['fqdn']} --schedulable=${schedulability} --config=admin.kubeconfig"
    environment(
      'schedulability' => !nodes.key?(:schedulable) && node_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] } ? 'True' : nodes['schedulable'].to_s
    )
    cwd Chef::Config[:file_cache_path]
    not_if do
      master_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] }
    end
  end

  execute "Set Labels for node : #{nodes['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} label node #{nodes['fqdn']} ${labels} --overwrite --config=admin.kubeconfig"
    environment(
      'labels' => nodes['labels'].to_s
    )
    cwd Chef::Config[:file_cache_path]
    only_if do
      nodes.key?('labels')
    end
  end
end
