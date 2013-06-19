require 'fileutils'

YAST_DIR = '/usr/share/YaST2/'

task :install do
  files = {
    'src/clients' => File.join(YAST_DIR, 'clients'),
    'src/modules' => File.join(YAST_DIR, 'modules'),
  }

  files.each {
    |dir, install_to|
    Dir.foreach(dir) do |file|
      file_path = File.join(dir, file)
      next unless File.file?(file_path)
      puts "Installing #{file_path} -> #{install_to}"

      begin
        FileUtils.cp(file_path, install_to)
      rescue => e
        puts "Cannot instal file #{file_path} to #{install_to}: #{e.message}"
      end
    end
  }
end

task :default => 'install'
