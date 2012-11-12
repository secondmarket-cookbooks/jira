#
# Cookbook Name:: jira
# Recipe:: server
#
# Copyright 2012, SecondMarket Labs, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "java::oracle"

execute "untar-jira-tarball" do
  cwd node['jira']['parentdir']
  command "tar zxf #{Chef::Config[:file_cache_path]}/#{node['jira']['tarball']}"
  action :nothing
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node['jira']['tarball']}" do
  source node['jira']['url']
  action :nothing
  notifies :run, "execute[untar-jira-tarball]", :immediately
end

http_request "HEAD #{node['jira']['url']}" do
  message ""
  url node['jira']['url']
  action :head
  if File.exists?("#{Chef::Config[:file_cache_path]}/#{node['jira']['tarball']}")
    headers "If-Modified-Since" => File.mtime("#{Chef::Config[:file_cache_path]}/#{node['jira']['tarball']}").httpdate
  end
  notifies :create, resources(:remote_file => "#{Chef::Config[:file_cache_path]}/#{node['jira']['tarball']}"), :immediately
end

user "jira" do
  comment "Atlassian JIRA"
  home node['jira']['datadir']
  system true
  action :create
end

template "/etc/profile.d/jira.sh" do
  source "jira-profile.sh.erb"
  owner "root"
  group "root"
  mode  00755
  variables(
    :jira_home => node['jira']['datadir']
  )
  action :create
end

directory node['jira']['datadir'] do
  owner "jira"
  mode 00755
  action :create
end

# Per https://confluence.atlassian.com/display/JIRA051/Installing+JIRA+from+an+Archive+File+on+Windows%2C+Linux+or+Solaris only these dirs need to be owned by "jira"
%w{logs temp work}.each do |d|
  directory "#{node['jira']['homedir']}/#{d}" do
    owner "jira"
    mode 00755
    action :create
  end
end

template "#{node['jira']['homedir']}/atlassian-jira/WEB-INF/classes/jira-application.properties" do
  source "jira-application.properties.erb"
  owner "root"
  group "root"
  mode  00644
  variables(
    :jira_workdir => node['jira']['datadir']
  )
  action :create
  notifies :restart, "service[jira]"
end

template "/etc/init.d/jira" do
  source "jira.init.erb"
  owner "root"
  group "root"
  mode  00755
  variables(
    :jira_base => node['jira']['homedir']
  )
  action :create
end

service "jira" do
  supports :restart => true
  action [:enable, :start]
end
