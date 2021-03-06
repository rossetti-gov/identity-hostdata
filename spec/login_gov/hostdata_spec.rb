require "spec_helper"

RSpec.describe LoginGov::Hostdata do
  it "has a version number" do
    expect(LoginGov::Hostdata::VERSION).not_to be nil
  end

  around(:each) do |ex|
    LoginGov::Hostdata.reset!

    FakeFS.with_fresh do
      ex.run
    end
  end

  describe '.domain' do
    context 'when /etc/login.gov exists (in a datacenter environment)' do
      before { FileUtils.mkdir_p('/etc/login.gov') }

      context 'when the info/domain file exists' do
        before do
          FileUtils.mkdir_p('/etc/login.gov/info')
          File.open('/etc/login.gov/info/domain', 'w') { |f| f.puts 'identitysandbox.gov' }
        end

        it 'reads the contents of the file' do
          expect(LoginGov::Hostdata.domain).to eq('identitysandbox.gov')
        end
      end

      context 'when the info/domain file does not exist' do
        it 'blows up' do
          expect { LoginGov::Hostdata.domain }.
            to raise_error(LoginGov::Hostdata::MissingConfigError)
        end
      end
    end

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is nil' do
        expect(LoginGov::Hostdata.domain).to eq(nil)
      end
    end
  end

  describe '.env' do
    context 'when /etc/login.gov exists (in a datacenter environment)' do
      before { FileUtils.mkdir_p('/etc/login.gov') }

      context 'when the info/env file exists' do
        before do
          FileUtils.mkdir_p('/etc/login.gov/info')
          File.open('/etc/login.gov/info/env', 'w') { |f| f.puts 'staging' }
        end

        it 'reads the contents of the file' do
          expect(LoginGov::Hostdata.env).to eq('staging')
        end
      end

      context 'when the info/env file does not exist' do
        it 'blows up' do
          expect { LoginGov::Hostdata.env }.
            to raise_error(LoginGov::Hostdata::MissingConfigError)
        end
      end
    end

    context 'when /etc/login.gov does not exist (development environment)' do
      it 'is nil' do
        expect(LoginGov::Hostdata.env).to eq(nil)
      end
    end
  end

  describe '.in_datacenter?' do
    it 'is true when the /etc/login.gov directory exists' do
      FileUtils.mkdir_p('/etc/login.gov')

      expect(LoginGov::Hostdata.in_datacenter?).to eq(true)
    end

    it 'is false when the /etc/login.gov does not exist' do
      expect(LoginGov::Hostdata.in_datacenter?).to eq(false)
    end
  end

  describe '.in_datacenter' do
    context 'when the /etc/login.gov directory exists' do
      before { FileUtils.mkdir_p('/etc/login.gov') }

      it 'blows up without a block' do
        expect { LoginGov::Hostdata.in_datacenter }.to raise_error(LocalJumpError)
      end

      it 'yields to its block with itself' do
        called = false

        LoginGov::Hostdata.in_datacenter do |hostdata|
          called = true

          expect(hostdata).to eq(LoginGov::Hostdata)
        end

        expect(called).to eq(true)
      end
    end

    context 'when the /etc/login.gov does not exist' do
      it 'blows up without a block' do
        expect { LoginGov::Hostdata.in_datacenter }.to raise_error(LocalJumpError)
      end

      it 'does not call its block (no-op)' do
        called = false

        LoginGov::Hostdata.in_datacenter { called = true }

        expect(called).to eq(false)
      end
    end
  end

  describe '.s3' do
    before do
      stub_request(:get, 'http://169.254.169.254/2016-09-02/dynamic/instance-identity/document').
        to_return(body: {
          'accountId' => '12345',
          'region' => 'us-east-1',
        }.to_json)

      FileUtils.mkdir_p('/etc/login.gov/info')
      File.open('/etc/login.gov/info/env', 'w') { |f| f.puts 'int' }
    end

    subject(:s3) { LoginGov::Hostdata.s3 }

    it 'builds an S3 instance with a bucket name based on EC2 instance data' do
      expect(s3.env).to eq('int')
      expect(s3.region).to eq('us-east-1')
      expect(s3.bucket).to eq('login-gov.app-secrets.12345-us-east-1')
    end

    context 'with an s3_client param' do
      let(:s3_client) { LoginGov::Hostdata::FakeS3Client.new }

      subject(:s3) { LoginGov::Hostdata.s3(s3_client: s3_client) }

      it 'passes s3_client through' do
        expect(s3.send(:s3_client)).to eq(s3_client)
      end
    end

    context 'with a logger param' do
      let(:logger) { Logger.new(STDOUT) }

      subject(:s3) { LoginGov::Hostdata.s3(logger: logger) }

      it 'passes the logger through' do
        expect(s3.logger).to eq(logger)
      end
    end
  end

  describe '.logger' do
    it 'has a default value' do
      expect(LoginGov::Hostdata.logger).to be
    end

    it 'has a setter' do
      logger = Logger.new(STDOUT)

      LoginGov::Hostdata.logger = logger

      expect(LoginGov::Hostdata.logger).to eq(logger)
    end
  end
end
