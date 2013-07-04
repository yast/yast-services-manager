require 'fileutils'
require 'tmpdir'
require 'rake/testtask'

YAST_DIR = '/usr/share/YaST2/'
YAST_DESKTOP = '/usr/share/applications/YaST2/'
PACKAGE_ARCHIVE = './package/yast2-services-manager.tar.bz2'
DOMAIN = 'services-manager'
PACKAGE_NAME = 'yast2-' + DOMAIN
DESTDIR = ENV['DESTDIR'] || '/'

FILES = {
  'Rakefile'     => nil,
  'src/clients'  => File.join(YAST_DIR, 'clients'),
  'src/modules'  => File.join(YAST_DIR, 'modules'),
  'src/includes' => File.join(YAST_DIR, 'include', DOMAIN),
  'src/desktop'  => File.join(YAST_DESKTOP),
  'test'         => nil,
  'test/unit'    => nil,
}

task :install do
  FILES.each {
    |dir, install_to|
    next if install_to.nil?

    install_to = File.join(DESTDIR, install_to)

    Dir.foreach(dir) do |file|
      file_path = File.join(dir, file)
      next unless File.file?(file_path)

      begin
        FileUtils.mkdir_p(install_to, :verbose => true)
        FileUtils.install(file_path, install_to, :verbose => true)
      rescue => e
        puts "Cannot instal file #{file_path} to #{install_to}: #{e.message}"
      end
    end
  }
end

task :package do
  project_dir = File.dirname(File.expand_path(__FILE__))
  workdir = File.expand_path(File.dirname(PACKAGE_ARCHIVE))

  Dir.mktmpdir("#{PACKAGE_NAME}-") {
    |tmpdir|
    puts "Working in temporary directory: #{tmpdir}"
    workdir = tmpdir

    archive_dir = File.join(workdir, PACKAGE_NAME)
    FileUtils.mkdir_p(archive_dir, :verbose => true)

    FILES.each {
      |dir, install_to|

      if File.file?(dir)
        FileUtils.cp(dir, archive_dir, :verbose => true)
      else
        dest_dir = File.join(archive_dir, dir)
        FileUtils.mkdir_p(dest_dir, :verbose => true)
        Dir.foreach(dir) do |file|
          file_path = File.join(dir, file)
          next unless File.file?(file_path)
          FileUtils.cp(file_path, dest_dir, :verbose => true)
        end
      end
    }

    `tar -C #{workdir} -cjvf #{PACKAGE_ARCHIVE} #{PACKAGE_NAME}`
  }
end

task :test do
  Rake::TestTask.new do |t|
    t.libs = ["lib"]
    t.warning = false
    t.verbose = true
    t.test_files = FileList['test/unit/*.rb']
  end
end

task :default => 'install'
