require 'pathname'

module MRuby
  module Gem
    class << self
      attr_accessor :processing_path
    end

    class Specification
      include Rake::DSL

      attr_reader :build
      attr_accessor :name, :dir

      def self.attr_array(*vars)
        attr_reader *vars
        vars.each do |v|
          class_eval "def #{v}=(val);@#{v}||=[];@#{v}+=[val].flatten;end"
        end
      end

      attr_array :licenses, :authors
      alias :license= :licenses=
      alias :author= :authors=
      attr_array :cflags
      attr_array :mruby_cflags, :mruby_includes, :mruby_ldflags, :mruby_libs

      attr_array :rbfiles, :objs
      attr_array :test_objs, :test_rbfiles
      attr_accessor :test_preload

      def initialize(name, &block)
        @name = name
        @build = MRuby.build
        @dir = Gem.processing_path
        @cflags = []
        @mruby_cflags, @mruby_ldflags, @mruby_libs = [], [], []
        @mruby_includes = ["#{dir}/include"]
        @rbfiles = Dir.glob("#{dir}/mrblib/*.rb")
        @objs = Dir.glob("#{dir}/src/*.{c,cpp,m,asm,S}").map { |f| f.relative_path_from(@dir).to_s.pathmap("#{build_dir}/%X.o") }
        @test_rbfiles = Dir.glob("#{dir}/test/*.rb")
        @test_objs = Dir.glob("#{dir}/test/*.{c,cpp,m,asm,S}").map { |f| f.relative_path_from(dir).to_s.pathmap("#{build_dir}/%X.o") }
        @test_preload = 'test/assert.rb'

        instance_eval(&block)

        @objs << "#{build_dir}/gem_init.o"

        if !name || !licenses || !authors
          fail "#{name || dir} required to set name, license(s) and author(s)"
        end

        build.gems << self
        build.libmruby << @objs

        define_default_rules
        add_tasks
      end

      def testlib
        "#{build_dir}/libmrb-#{name}-gem-test.a"
      end

      def funcname
        @funcname ||= @name.gsub('-', '_')
      end

      def build_dir
        return @build_dir if @build_dir
        @build_dir = "#{build.build_dir}/mrbgems/#{name}"
        FileUtils.mkdir_p @build_dir
        @build_dir
      end

      def add_tasks
        test_rbc = "#{build_dir}/gem_test.c"
        test_rbobj = test_rbc.ext('o')

        Rake::FileTask.define_task testlib => test_objs + [test_rbobj] do |t|
          build.archive t.name, 'rs', t.prerequisites
        end

        Rake::FileTask.define_task test_rbobj => test_rbc
        Rake::FileTask.define_task test_rbc => [build.mrbcfile] + test_rbfiles do |t|
          open(t.name, 'w') do |f|
            f.puts gem_init_header
            build.compile_mruby f, test_rbfiles, "gem_test_irep_#{funcname}" unless test_rbfiles.empty?
          end

          open(t.name, 'a') do |f|
            f.puts "void mrb_#{funcname}_gem_test(mrb_state *mrb);" unless test_objs.empty?
            f.puts "void GENERATED_TMP_mrb_#{funcname}_gem_test(mrb_state *mrb) {"
            f.puts "  mrb_#{funcname}_gem_test(mrb);" unless test_objs.empty? 
            f.puts <<__EOF__ unless test_rbfiles.empty?
  mrb_load_irep(mrb, gem_test_irep_#{funcname});
  if (mrb->exc) {
    mrb_p(mrb, mrb_obj_value(mrb->exc));
    exit(0);
  }

__EOF__
            f.puts "}"
          end
        end

        Rake::FileTask.define_task "#{build_dir}/gem_init.o" => "#{build_dir}/gem_init.c"
        Rake::FileTask.define_task "#{build_dir}/gem_init.c" => [build.mrbcfile] + rbfiles do |t|
          generate_gem_init(t.name)
        end
      end

      def define_default_rules
        obj_matcher = Regexp.new("^#{build_dir}/(.*)\\.o$")
        {
          '.c' => proc { |t| build.compile_c t.name, t.prerequisites.first, cflags },
          '.cpp' => proc { |t| build.compile_cxx t.name, t.prerequisites.first, cflags },
          '.m' => proc { |t| build.compile_objc t.name, t.prerequisites.first, cflags },
          '.S' => proc { |t| build.compile_asm t.name, t.prerequisites.first, cflags }
        }.each do |ext, compile|
          rule obj_matcher => [
            proc { |file|
              file.sub(obj_matcher, "#{dir}/\\1#{ext}")
            },
            proc { |file|
              get_dependencies(file)
            }] do |t|
            FileUtils.mkdir_p File.dirname(t.name)
            compile.call t
          end

          rule obj_matcher => [
            proc { |file|
              file.sub(obj_matcher, "#{build_dir}/\\1#{ext}")
            },
            proc { |file|
              get_dependencies(file)
            }] do |t|
            FileUtils.mkdir_p File.dirname(t.name)
            compile.call t
          end
        end
      end

      def generate_gem_init(fname)
        open(fname, 'w') do |f|
          f.puts gem_init_header
          build.compile_mruby f, rbfiles, "gem_mrblib_irep_#{funcname}" unless rbfiles.empty?
          f.puts "void mrb_#{funcname}_gem_init(mrb_state *mrb);"
          f.puts "void GENERATED_TMP_mrb_#{funcname}_gem_init(mrb_state *mrb) {"
          f.puts "  mrb_#{funcname}_gem_init(mrb);" unless objs.empty?
          f.puts <<__EOF__ unless rbfiles.empty?
  mrb_load_irep(mrb, gem_mrblib_irep_#{funcname});
  if (mrb->exc) {
    mrb_p(mrb, mrb_obj_value(mrb->exc));
    exit(0);
  }

__EOF__
          f.puts "}"
        end
      end # generate_gem_init

      def gem_init_header
        <<__EOF__
/*
 * This file is loading the irep
 * Ruby GEM code.
 *
 * IMPORTANT:
 *   This file was generated!
 *   All manual changes will get lost.
 */
#include "mruby.h"
#include "mruby/irep.h"
#include "mruby/dump.h"
#include "mruby/string.h"
#include "mruby/proc.h"
__EOF__
      end # gem_init_header

    end # Specification
  end # Gem
end # MRuby