require 'fileutils'
namespace :app do  
  task :configure => :environment do
    config_path = File.join(APP_ROOT, 'config')
    conf = Bowline.configuration
    
    # Titanium complains about whitespace
    manifest =  <<-EOF
#appname:#{conf.name}
#appid:#{conf.id}
#publisher:#{conf.publisher}
#image:public/logo.png
#url:#{conf.url}
#guid:0e70684a-dd4b-4d97-9396-6bc01ba10a4e
#desc:#{conf.description}
#type:desktop
runtime:0.4.4
api:0.4.4
tiapp:0.4.4
tifilesystem:0.4.4
tiplatform:0.4.4
tiui:0.4.4
javascript:0.4.4
ruby:0.4.4
tidatabase:0.4.4
tidesktop:0.4.4
tigrowl:0.4.4
timedia:0.4.4
timonkey:0.4.4
tinetwork:0.4.4
tinotification:0.4.4
tiprocess:0.4.4
    EOF
    
    conf.publisher ||= 'Bowline'
    conf.copyright ||= "Copyright © #{Time.now.year}"
    
    tiapp = <<-EOF
<?xml version='1.0' encoding='UTF-8'?>
<ti:app xmlns:ti='http://ti.appcelerator.org'>
  <id>#{conf.id}</id>
  <name>#{conf.name}</name>
  <version>#{conf.version}</version>
  <publisher>#{conf.publisher}</publisher>
  <url>#{conf.url}</url>
  <icon>public/icon.png</icon>
  <copyright>#{conf.copyright}</copyright>
  <window>
    <id>initial</id>
    <title>#{conf.name}</title>
    <url>app://public/index.html</url>
    <width>700</width>
    <max-width>3000</max-width>
    <min-width>0</min-width>
    <height>800</height>
    <max-height>3000</max-height>
    <min-height>0</min-height>
    <fullscreen>false</fullscreen>
    <resizable>true</resizable>
    <chrome scrollbars="true">true</chrome>
    <maximizable>true</maximizable>
    <minimizable>true</minimizable>
    <closeable>true</closeable>
  </window>
</ti:app>
    EOF
    
    FileUtils.cd(config_path) do
      File.open('manifest', 'w+') {|f| f.write manifest }
      File.open('tiapp.xml', 'w+') {|f| f.write tiapp }
    end
  end
  
  desc "Bundles up app into executables"  
  task :bundle do
    build_path  = File.join(APP_ROOT, 'build')
    app_path    = File.join(build_path, 'app')
    config_path = File.join(APP_ROOT, 'config')
    
    tiapp    = File.join(config_path, 'tiapp.xml')
    manifest = File.join(config_path, 'manifest')
    env      = File.join(config_path, 'environment.rb')
        
    if !File.exists?(tiapp) || 
        !File.exists?(manifest)
      Rake::Task['app:configure'].invoke
    elsif File.mtime(tiapp) < File.mtime(env)
      puts "You may need to run 'rake app:configure'"
    end
    
    FileUtils.rm_rf(app_path)
    FileUtils.makedirs(app_path)
    
    FileUtils.cp(tiapp,    app_path)
    FileUtils.cp(manifest, app_path)
    
    dirs = Dir[File.join(APP_ROOT, '**')]
    dirs.delete(build_path)
    dirs.delete(File.join(APP_ROOT, 'log'))
    dirs.delete(File.join(APP_ROOT, 'tmp'))
    dirs.delete(File.join(APP_ROOT, 'db'))
    dirs.delete_if {|i| i =~ /\.svn|\.DS_Store/ }
    
    FileUtils.cd(app_path) do
      FileUtils.makedirs('Resources')
      FileUtils.cp_r(dirs, 'Resources')
      schema_path = File.join(APP_ROOT, 'db', 'schema.rb')
      if File.exists?(schema_path)
        FileUtils.cp(
          schema_path, 
          File.join('Resources', 'db')
        )
      end
    end
  end
  
  desc "Use the Titanium SDK to build the app"
  task :build do
    build_path    = File.join(APP_ROOT, 'build')
    app_path      = File.join(build_path, 'app')

    ti_path = ENV['TIPATH'] ? ENV['TIPATH'].dup : begin 
      if RUBY_PLATFORM =~ /darwin/
        '/Library/Application Support/Titanium'
      elsif RUBY_PLATFORM =~ /win/
        'C:/ProgramData/Titanium'
      elsif RUBY_PLATFORM =~ /linux/
        '/opt/titanium'
      else
        raise "Unknown platform"
      end
    end

    unless File.directory?(ti_path)
      raise "Titanium SDK not found, " \
              "install the SDK or " \
              "specify the ENV variable TIPATH"
    end

    ti_lib_path = Dir[File.join(ti_path, "sdk", "*", "*")][-1]

    # Space in osx path
    ti_path.gsub!(' ', '\ ')
    ti_lib_path.gsub!(' ', '\ ')

    command = ['python']
    command << File.join(ti_lib_path, "tibuild.py")
    command << "-d #{build_path}"
    command << "-s #{ti_path}"
    command << "-r" if ENV['TIRUN']
    command << "-a #{ti_lib_path}"
    command << app_path

    exec(command.join(' '))
  end
end

desc "Bundle and build app"
task :app => ["app:bundle", "app:build"]