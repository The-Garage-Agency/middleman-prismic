require 'middleman-core/cli'
require 'yaml'
require 'fileutils'
require 'digest'

module Middleman
  module Cli
    class Prismic < Thor::Group
      # Path where Middleman expects the local data to be stored
      DATA_DIR = 'data/prismic'.freeze

      class_option(
        :ref,
        type: :string,
        desc: "Pull content from Prismic by ref instead of configured release",
      )

      check_unknown_options!

      namespace :prismic
      desc 'Import data from Prismic'

      def self.source_root
        ENV['MM_ROOT']
      end

      # Tell Thor to exit with a nonzero exit code on failure
      def self.exit_on_failure?
        true
      end

      def prismic
        create_directories
        output_documents_by_locale
        output_references
        output_custom_queries
      end

      private

      def create_directories
        if File.exists?(DATA_DIR)
          FileUtils.rm_rf(Dir.glob(DATA_DIR))
        end

        FileUtils.mkdir_p(DATA_DIR)
      end

      def paginate_documents_for_locale(locale)
        page = 0

        begin
          page += 1
          request = api.form('everything', { lang: locale }).page(page)
          response = api_response(request)

          output_available_documents(response, locale)
        end while page < response.total_pages
      end

      def output_available_documents(response, locale)
        response.group_by(&:type).each do |document_type, documents|
          document_dir = File.join(DATA_DIR, locale, document_type.pluralize)
          write_collection(document_dir, documents)
        end
      end

      def output_references
        File.open(File.join(DATA_DIR, 'reference.yml'), 'w') do |f|
          f.write(api.master_ref.to_yaml)
        end
      end

      def output_documents_by_locale
        Middleman::Prismic.options.locales.each do |locale|
          FileUtils.mkdir_p(File.join(DATA_DIR, locale))
          paginate_documents_for_locale(locale)
        end
      end

      def api_response(form)
        form.submit(api_reference)
      end

      def api_form
        @api_form ||= api.form('everything')
      end

      def api_reference
        options[:ref] || api.ref(Middleman::Prismic.options.release)
      end

      def api
        @api ||= ::Prismic.api(Middleman::Prismic.options.api_url, Middleman::Prismic.options.access_token)
      end

      def write_collection(dir, collection)
        FileUtils.mkdir_p(dir)

        collection.each do |item|
          filename = "#{Digest::MD5.hexdigest(item.id)}.yml"

          File.write(
            File.join(dir, filename),
            item.to_yaml
          )
        end
      end

      Base.register(self, 'prismic', 'prismic [options]', 'Get data from Prismic')
    end
  end
end
