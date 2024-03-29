require 'erb'

module FlashDevelop
  class Project
    attr_reader :class_name, 
                :bin_path,
                :src_path,
                :test_path,
                :doc_path,
                :debug_swf_name,
                :test_swf_name,
                :test_runner_name

    def initialize
      @doc_path = 'doc'
      @bin_path = 'bin'
      @src_path = 'src'
      @test_path = 'test'
      @debug_swf_name = 'debug.swf'
      @test_swf_name = 'test.swf'
      @test_runner_name = 'test_runner.swf'
    end

    def flash_develop_to_sprouts!(project_root)
      File.open('Gemfile', 'w+') {|f| f.write(gemfile_template) } unless File.exists?('Gemfile')

      rakefile = !Dir['rakefile.rb'].first
      as3proj_file = Dir['*.as3proj'].first

      unless rakefile
        generate_sprout_files!(projet_root)

        if as3proj_file
          parse_as3proj(as3proj_file)
        end
      end
    end

    def build_options= options
      options.each_pair do |name, value|
        self.instance_variable_set(:"@#{name}", value)
      end
    end

    def generate_sprout_files!(project_root)
      gem_root = Gem.loaded_specs['flashsdk'].full_gem_path
      templates_path = File.join(gem_root, 'lib/flashsdk/generators/templates/')
      ['Gemfile', 'rakefile.rb'].each do |file|
        contents = open("#{templates_path}#{file}").read

        if file == 'rakefile.rb'
          template = ERB.new(contents)

          # Set rakefile variables
          class_name = @class_name
          bin = @bin_path
          src = @src_path
          doc = @doc_path
          debug_swf_name = @debug_swf_name
          test_swf_name = @test_swf_name
          test_runner_name = @test_runner_name

          contents = template.result(binding)

          # debug
          debug_matches = contents.match(/mxmlc \"[^\"]*\" do \|t\|([\s|.|a-zA-Z\._<\"'=\/]*)end/)
          debug_begin, debug_end = debug_matches[0].split(debug_matches[1])
          contents.gsub!(debug_matches[0], "#{debug_begin}#{debug_matches[1].concat(self.mxmlc_options)}#{debug_end}")

          # test suite
          #test_matches = contents.match(/mxmlc \"[^\"]*\" => :asunit4 do \|t\|([\s|.|a-zA-Z\._<\"'=\/]*)end/)
          #test_begin, test_end = test_matches[0].split(test_matches[1])
          #contents.gsub!(test_matches[0], "#{test_begin}#{test_matches[1].concat(self.mxmlc_options)}#{test_end}")

          # swc
          #lib_regexp = /compc \"[^\"]*\" do \|t\|([\s|.|a-zA-Z\._<\"'=\/]*)end/
          #lib_begin, lib_end = lib_matches[0].split(lib_matches[1])
          #contents.gsub!(lib_matches[0], "#{lib_begin}#{lib_matches[1].concat(self.mxmlc_options)}#{lib_end}")
        end

        File.open("#{project_root}/#{file}", "w+") {|f| f.write(contents) }
      end
    end

    def parse_as3proj(as3proj_file)
      @build_options = {}

      #
      # NOTE:
      # Can't use Nokogiri inside VIM. Need to try a native XML parsing library.
      #
      as3proj = Nokogiri::XML(open( as3proj_file ))

      output_name = File.basename(as3proj.css('output > movie[path]').attr('path').value.gsub('\\', '/'), '.swf')
      @debug_swf_name = "#{output_name}-debug.swf"
      @test_swf_name = "#{output_name}-test.swf"

      @build_options['as3'] = true
      @build_options['class_name'] = File.basename(as3proj.css('compileTargets > compile[path]').attr('path').value.gsub('\\', '/'), '.as')
      @build_options['default_size'] = "#{as3proj.css('output > movie[width]').attr('width').value} #{as3proj.css('output > movie[height]').attr('height').value}"
      @build_options['source_path'] = as3proj.css('classpaths > class').collect {|node| node.attr('path').gsub('\\', '/') }
      @build_options['library_path'] = as3proj.css('libraryPaths > element[path]').collect {|node| node.attr('path').gsub('\\', '/') }
      #@build_options['include_libraries'] = as3proj.css('includeLibraries > element[path]').collect {|node| node.attr('path').gsub('\\', '/') }
      #@build_options['external_library_path'] = as3proj.css('externalLibraryPaths > element[path]').collect {|node| node.attr('path').gsub('\\', '/') }
      #@build_options['rsl'] = as3proj.css('rslPaths > element[path]').collect {|node| node.attr('path').gsub('\\', '/') }

      # Build options
      as3proj.css('build > option').each do |option|
        value = option.attributes.first[1].value
        next if value.empty?

        # Transform default boolean values
        value = ((value.index(/true/i)) ? '' : 0) if value.index(/true|false/i) == 0
        next if value == 0

        option_name = option.attributes.first[1].name.gsub(/[A-Z]/, '-\0').downcase.gsub('-', '_')
        @build_options[option_name] = value
      end

      @build_options
    end

    protected
      def mxmlc_options
        rake_statements = ""
        @build_options.each_pair do |k, value|
          assignment = (value.kind_of?(Array)) ? '<<' : '='
          values = value.kind_of?(Array)? value : [value]
          values.each do |v|
            rake_statements += "\tt.#{k} #{assignment} #{v.inspect}\n"
          end
        end
        rake_statements
      end

  end
end
