# frozen_string_literal: true

module Licensed
  module Bundler
    module DefinitionExtensions
      attr_accessor :force_exclude_groups

      # Override specs to avoid logic that would raise Gem::NotFound
      # which is handled in this ./missing_specification.rb, and to not add
      # bundler as a dependency if it's not a user-requested gem.
      #
      # Newer versions of Bundler have changed the implementation of specs_for
      # as well which no longer calls this function.  Overriding this function
      # gives a stable access point for licensed
      def specs
        @specs ||= begin
          specs = resolve.materialize(requested_dependencies)

          all_dependencies = requested_dependencies.concat(specs.flat_map(&:dependencies))
          if all_dependencies.any? { |d| d.name == "bundler" } && !specs["bundler"].any?
            if ::Bundler::VERSION >= "2.4.1"
              query = ["bundler", ::Bundler::VERSION]
            else
              query = Gem::Dependency.new("bundler", ::Bundler::VERSION)
            end
            bundler = sources.metadata_source.specs.search(query).last
            specs["bundler"] = bundler
          end

          specs
        end
      end

      # Override requested_groups to also exclude any groups that are
      # in the "bundler.without" section of the licensed configuration file.
      def requested_groups
        super - Array(force_exclude_groups)
      end
    end
  end
end
