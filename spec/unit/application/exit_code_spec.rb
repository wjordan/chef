#
# Author:: Steven Murawski (<smurawski@chef.io>)
# Copyright:: Copyright 2016, Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef"
require "spec_helper"

require "chef/application/exit_code"

describe Chef::Application::ExitCode do

  let(:exit_codes) { Chef::Application::ExitCode }

  context "Validates the return codes from RFC 062" do

    before do
      allow(Chef::Config).to receive(:[]).with(:exit_status).and_return(:enabled)
    end

    it "validates a SUCCESS return code of 0" do
      expect(exit_codes.valid?(0)).to eq(true)
    end

    it "validates a GENERIC_FAILURE return code of 1" do
      expect(exit_codes.valid?(1)).to eq(true)
    end

    it "validates a AUDIT_MODE_FAILURE return code of 42" do
      expect(exit_codes.valid?(42)).to eq(true)
    end

    it "validates a REBOOT_SCHEDULED return code of 35" do
      expect(exit_codes.valid?(35)).to eq(true)
    end

    it "validates a REBOOT_NEEDED return code of 37" do
      expect(exit_codes.valid?(37)).to eq(true)
    end

    it "validates a REBOOT_NOW return code of 40" do
      expect(exit_codes.valid?(40)).to eq(true)
    end

    it "validates a REBOOT_FAILED return code of 41" do
      expect(exit_codes.valid?(41)).to eq(true)
    end

  end

  context "when Chef::Config :exit_status is not configured" do
    before do
      allow(exit_codes).to receive(:skip_validation).and_return(false)
      allow(exit_codes).to receive(:allow_deprecated_exit_code).and_return(true)
    end

    it "validates any exit code" do
      expect(exit_codes.valid?(151)).to eq(true)
    end

    it "writes a deprecation warning" do
      warn = "Chef RFC 62 (https://github.com/chef/chef-rfc/master/rfc062-exit-status.md) defines the" \
      " exit codes that should be used with Chef.  Chef::Application::ExitCode defines valid exit codes"  \
      " In a future release, non-standard exit codes will be redefined as" \
      " GENERIC_FAILURE unless `exit_status` is set to `:disabled` in your client.rb."
      expect(Chef).to receive(:log_deprecation).with(warn)
      expect(exit_codes.valid?(151)).to eq(true)
    end

    it "does not modify non-RFC exit codes" do
      expect(exit_codes.validate_exit_code(151)).to eq(151)
    end

    it "returns DEPRECATED_FAILURE when no exit code is specified" do
      expect(exit_codes.validate_exit_code()).to eq(-1)
    end

    it "returns GENERIC_FAILURE when an exception is specified" do
      expect(exit_codes.validate_exit_code(Exception.new('BOOM'))).to eq(1)
    end

  end

  context "when Chef::Config :exit_status is configured to not validate exit codes" do
    before do
      allow(exit_codes).to receive(:skip_validation).and_return(true)
      allow(exit_codes).to receive(:allow_deprecated_exit_code).and_return(true)
    end

    it "validates any exit code" do
      expect(exit_codes.valid?(151)).to eq(true)
    end

    it "does not write a deprecation warning" do
      warn = "Chef RFC 62 (https://github.com/chef/chef-rfc/master/rfc062-exit-status.md) defines the" \
      " exit codes that should be used with Chef.  Chef::Application::ExitCode defines valid exit codes"  \
      " In a future release, non-standard exit codes will be redefined as" \
      " GENERIC_FAILURE unless `exit_status` is set to `:disabled` in your client.rb."
      expect(Chef).not_to receive(:log_deprecation).with(warn)
      expect(exit_codes.valid?(151)).to eq(true)
    end

    it "does not modify non-RFC exit codes" do
      expect(exit_codes.validate_exit_code(151)).to eq(151)
    end

    it "returns DEPRECATED_FAILURE when no exit code is specified" do
      expect(exit_codes.validate_exit_code()).to eq(-1)
    end

    it "returns GENERIC_FAILURE when an exception is specified" do
      expect(exit_codes.validate_exit_code(Exception.new('BOOM'))).to eq(1)
    end

    it "returns SUCCESS when a reboot is pending" do
      allow(Chef::DSL::RebootPending).to receive(:reboot_pending?).and_return(true)
      expect(exit_codes.validate_exit_code(0)).to eq(0)
    end
  end

  context "when Chef::Config :exit_status is configured to validate exit codes" do
    before do
      allow(exit_codes).to receive(:skip_validation).and_return(false)
      allow(exit_codes).to receive(:allow_deprecated_exit_code).and_return(false)
    end

    it "returns false for non-RFC exit codes" do
      expect(exit_codes.valid?(151)).to eq(false)
    end

    it "does write a deprecation warning" do
      warn = "Chef RFC 62 (https://github.com/chef/chef-rfc/master/rfc062-exit-status.md) defines the" \
      " exit codes that should be used with Chef.  Chef::Application::ExitCode defines valid exit codes"  \
      " In a future release, non-standard exit codes will be redefined as" \
      " GENERIC_FAILURE unless `exit_status` is set to `:disabled` in your client.rb."
      expect(Chef).to receive(:log_deprecation).with(warn)
      expect(exit_codes.valid?(151)).to eq(false)
    end

    it "returns a GENERIC_FAILURE for non-RFC exit codes" do
      expect(exit_codes.validate_exit_code(151)).to eq(1)
    end

    it "returns GENERIC_FAILURE when no exit code is specified" do
      expect(exit_codes.validate_exit_code()).to eq(1)
    end

    it "returns GENERIC_FAILURE when an exception is specified" do
      expect(exit_codes.validate_exit_code(Exception.new('BOOM'))).to eq(1)
    end

    it "returns AUDIT_MODE_FAILURE when there is an audit error" do
      audit_error = Chef::Exceptions::AuditError.new('BOOM')
      runtime_error = Chef::Exceptions::RunFailedWrappingError.new(audit_error)
      expect(exit_codes.validate_exit_code(runtime_error)).to eq(42)
    end

    it "returns REBOOT_NOW when there is an reboot requested" do
      reboot_error = Chef::Exceptions::Reboot.new('BOOM')
      runtime_error = Chef::Exceptions::RunFailedWrappingError.new(reboot_error)
      expect(exit_codes.validate_exit_code(runtime_error)).to eq(40)
    end

    it "returns REBOOT_FAILED when the reboot command fails" do
      reboot_error = Chef::Exceptions::RebootFailed.new('BOOM')
      runtime_error = Chef::Exceptions::RunFailedWrappingError.new(reboot_error)
      expect(exit_codes.validate_exit_code(runtime_error)).to eq(41)
    end
    
    it "returns REBOOT_NEEDED when a reboot is pending" do
      allow(Chef::DSL::RebootPending).to receive(:reboot_pending?).and_return(true)
      expect(exit_codes.validate_exit_code(0)).to eq(37)
    end
  end

end
