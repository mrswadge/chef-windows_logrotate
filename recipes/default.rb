if platform?('windows')
  cache_path = "#{Chef::Config[:file_cache_path]}\\#{node['windows_logrotate']['zip_filename']}"
  install_path = "#{node['windows_logrotate']['install_dir']}"
  logrotate_exe = File.join(install_path, 'logrotate.exe')
  logrotate_full_version = node['windows_logrotate']['version']
  logrotate_version = logrotate_full_version[0..logrotate_full_version.index('_')-1]

  ruby_block "prepare log rotate installer" do
    block do
      # Check if the previous chef-client run installed correctly.
      remove_cache = false
      if File.exist?(cache_path)
        if not File.exist?(logrotate_exe)
          puts "Detected logrotate is not installed properly."
          remove_cache = true
        end 
      end
      
      # Check we have the correct verison installed.
      if File.exist?(logrotate_exe)
        shell_out!("#{logrotate_exe} -v").stdout.each_line do |line|
          unless line.nil?
            vline = line[line.index(':')..-1].strip if line['logrotate: logrotate ']
            unless vline.nil?
              if not vline.include?(logrotate_version)
                puts "Detected different version of logrotate installed."
                remove_cache = true
                
                # uninstall the existing version.
                uninstall = Chef::Resource::WindowsPackage.new('LogRotate', run_context)
                uninstall.run_action(:remove)
              end
            end
          end
        end
      end
      
      File.delete(cache_path) if remove_cache and File.exist?(cache_path)
    end
  end
  
  remote_file "download #{node['windows_logrotate']['url']}" do
    path cache_path
    source node['windows_logrotate']['url']
    checksum node['windows_logrotate']['sha256']
    notifies :run, "powershell_script[unzip #{cache_path}]", :immediately
  end

  powershell_script "unzip #{cache_path}" do
    code "Expand-Archive -Path '#{cache_path}' -DestinationPath '#{Chef::Config[:file_cache_path]}' -Force;"
    action :nothing
    notifies :install, 'windows_package[LogRotate]', :immediately
  end

  windows_package 'LogRotate' do
    installer_type :custom
    options "/S /v\"/qn\" /v\"INSTALLDIR=#{node['windows_logrotate']['install_dir']}\""
    source "#{Chef::Config[:file_cache_path]}\\logrotateSetup.exe"
    action :nothing
  end
else
  Chef::Log.warn('LogRotate for Windows can only be installed on Windows platforms!')
end
