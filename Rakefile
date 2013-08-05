require 'fileutils'
require 'tmpdir'
require 'rake/testtask'

YAST_DIR = '/usr/share/YaST2/'
YAST_DESKTOP = '/usr/share/applications/YaST2/'
PACKAGE_ARCHIVE = './package/yast2-services-manager.tar.bz2'
DOMAIN = 'services-manager'
PACKAGE_NAME = 'yast2-' + DOMAIN
DESTDIR = ENV['DESTDIR'] || '/'
RNC_DESTINATION = YAST_DIR + '/schema/autoyast/rnc/'
DOCDIR = '/usr/share/doc/packages/' + PACKAGE_NAME

# Tells which files/dirs are used for build
#   key -> files/dirs (if mentioned, they are in resulting package)
#   val -> where they are installed (nil == not installed)
FILES = {
  'Rakefile'     => nil,
  'src/clients'  => File.join(YAST_DIR, 'clients'),
  'src/modules'  => File.join(YAST_DIR, 'modules'),
  'src/desktop'  => YAST_DESKTOP,
  'test'         => nil,
  'config'       => RNC_DESTINATION,
  'license'      => DOCDIR,
}

Rake::TaskManager.record_task_metadata = true

desc "Install the files on local system"
task :install do
  FILES.each do |dir, install_to|
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
  end
end

desc "Create a package in path #{PACKAGE_ARCHIVE}"
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

Rake::TestTask.new do |t|
  t.libs = ["lib"]
  t.warning = false
  t.verbose = true
  t.test_files = FileList['test/*_test.rb']
end

task :default do
  Rake.application.options.show_tasks = :tasks
  Rake.application.options.show_task_pattern = //
  Rake.application.display_tasks_and_comments
end
