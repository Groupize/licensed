# frozen_string_literal: true

require "English"
require "json"
require "parallel"

module Licensed
  module Sources
    class Pip < Source
      PACKAGE_INFO_SEPARATOR = "\n---\n"

      def enabled?
        pip_command && Licensed::Shell.tool_available?(pip_command)
      end

      def enumerate_dependencies
        packages.map do |package|
          Dependency.new(
            name: package["Name"],
            version: package["Version"],
            path: package_license_location(package),
            metadata: {
              "type"        => Pip.type,
              "summary"     => package["Summary"],
              "homepage"    => package["Home-page"]
            }
          )
        end
      end

      protected

      # Returns the command to run pip
      def pip_command
        return [] unless virtual_env_dir
        File.join(virtual_env_dir, "bin", "pip")
      end

      private

      # Returns the location of license files in the package, checking for the inclusion of a new `license_files`
      # folder per https://peps.python.org/pep-0639/
      def package_license_location(package)
        dist_info = File.join(package["Location"], package["Name"].gsub("-", "_") +  "-" + package["Version"] + ".dist-info")
        license_files = File.join(dist_info, "license_files")
        return File.exist?(license_files) ? license_files : dist_info
      end

      # Returns parsed information for all packages used by the project,
      # using `pip list` to determine what packages are used and `pip show`
      # to gather package information
      def packages
        all_packages = pip_show_command(package_names)
        all_packages.split(PACKAGE_INFO_SEPARATOR).reduce([]) do |accum, val|
          accum << parse_package_info(val)
        end
      end

      # Returns the names of all of the packages used by the current project,
      # as returned from `pip list`
      def package_names
        @package_names ||= begin
          JSON.parse(pip_list_command).map { |package| package["name"] }
        rescue JSON::ParserError => e
          message = "Licensed was unable to parse the output from 'npm list'. JSON Error: #{e.message}"
          raise Licensed::Sources::Source::Error, message
        end
      end

      # Returns a hash filled with package info parsed from the email-header formatted output
      # returned by `pip show`
      def parse_package_info(package_info)
        package_info.lines.each_with_object(Hash.new(0)) { |pkg, a|
          k, v = pkg.split(":", 2)
          next if k.nil? || k.empty?
          a[k.strip] = v&.strip
        }
      end

      # Returns the output from `pip list --format=json`
      def pip_list_command
        Licensed::Shell.execute(pip_command, "--disable-pip-version-check", "list", "--format=json")
      end

      # Returns the output from `pip show <package> <package> ...`
      def pip_show_command(packages)
        Licensed::Shell.execute(pip_command, "--disable-pip-version-check", "show", *packages)
      end

      def virtual_env_dir
        return @virtual_env_dir if defined?(@virtual_env_dir)
        @virtual_env_dir = begin
          python_config = config["python"]
          return unless python_config.is_a?(Hash)

          venv_dir = python_config["virtual_env_dir"]
          File.expand_path(venv_dir, config.root) if venv_dir
        end
      end
    end
  end
end
