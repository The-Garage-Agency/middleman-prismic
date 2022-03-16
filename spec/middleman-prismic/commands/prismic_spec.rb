require "spec_helper"

describe Middleman::Cli::Prismic do
  describe "#prismic", :in_temp_directory do
    it "creates the directory that prismic data should live in" do
      stub_options
      stub_prismic_api

      expect(File).not_to exist(described_class::DATA_DIR)

      described_class.new.prismic

      expect(File).to exist(described_class::DATA_DIR)
    end

    it "collects all paginated documents and writes them to file" do
      stub_options
      document = double("document", id: "thing", to_yaml: "yaml")
      response = double(
        "response",
        group_by: { "foo" => [document] },
        total_pages: 1,
      )
      stub_prismic_api(response)

      described_class.new.prismic

      file_path = File.join(described_class::DATA_DIR, "foos")

      expect(File).to exist(file_path)
      expect(Dir.entries(file_path) - [".", ".."]).
        to eq ["#{Digest::MD5.hexdigest(document.id)}.yml"]
    end

    it "outputs all references" do
      stub_options
      stub_prismic_api
      reference_path = File.join(described_class::DATA_DIR, "reference.yml")

      expect(File).not_to exist(reference_path)

      described_class.new.prismic

      expect(File).to exist(reference_path)
    end

    it "downloads via prismic ref" do
      stub_options
      response = double("response", group_by: [], total_pages: 1)
      reference = "reference"
      api_form = stub_prismic_api(response)
      allow(api_form).to receive(:submit).and_return(response)

      described_class.new([], ref: reference).prismic

      expect(api_form).to have_received(:submit).with(reference)
    end
  end

  def stub_options(hash = {})
    options = double(
      "options",
      {
        access_token: nil,
        api_url: "http://example.com",
        release: "release",
      }.merge(hash)
    )
    allow(Middleman::Prismic).to receive(:options).and_return(options)
  end

  def stub_prismic_api(response = double("response", group_by: [], total_pages: 1))
    api_form = double("api_form", page: double, submit: response)
    api = double("api", form: api_form, ref: double, master_ref: "ref")
    allow(Prismic).to receive(:api).and_return(api)
    api_form
  end
end
