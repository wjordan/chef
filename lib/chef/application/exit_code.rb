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
require "chef/dsl/reboot_pending"

class Chef
  class Application

    # These are the exit codes defined in Chef RFC 062
    # https://github.com/chef/chef-rfc/blob/master/rfc062-exit-status.md
    class ExitCode

      # -1 is defined as DEPRECATED_FAILURE in RFC 062, so it is
      # not enumerated in an active constant.
      #
      VALID_RFC_062_EXIT_CODES = {
        SUCCESS: 0,
        GENERIC_FAILURE: 1,
        REBOOT_SCHEDULED: 35,
        REBOOT_NEEDED: 37,
        REBOOT_NOW: 40,
        REBOOT_FAILED: 41,
        AUDIT_MODE_FAILURE: 42,
      }

      DEPRECATED_RFC_062_EXIT_CODES = {
        DEPRECATED_FAILURE: -1,
      }

      class << self

        def validate_exit_code(exit_code = nil)
          exit_code = resolve_exit_code(exit_code)
          return exit_code if valid?(exit_code)
          default_exit_code
        end

        def valid?(exit_code)
          return false if exit_code.nil?
          return true if skip_validation
          return true if valid_exit_codes.include? exit_code

          notify_on_deprecation
          allow_deprecated_exit_code
        end

        def allow_deprecated_exit_code
          ## TODO: change the check to just
          ## Chef::Config[:exit_status] == :disabled
          Chef::Config[:exit_status].nil? ||
            Chef::Config[:exit_status] != :enabled
        end

        private

        def resolve_exit_code(exit_code)
          return if exit_code.nil?
          case exit_code 
          when Fixnum
            resolve_fixnum_exit_code(exit_code)
          when Exception
            resolve_exit_code_from_exception(exit_code)
          end 
        end
        
        def resolve_fixnum_exit_code(exit_code)
          return exit_code if allow_deprecated_exit_code
          if reboot_needed?(exit_code)
            VALID_RFC_062_EXIT_CODES[:REBOOT_NEEDED]
          else
            exit_code
          end
        end

        def resolve_exit_code_from_exception(exception)
          if allow_deprecated_exit_code
            VALID_RFC_062_EXIT_CODES[:GENERIC_FAILURE]
          elsif reboot_now?(exception)
            VALID_RFC_062_EXIT_CODES[:REBOOT_NOW]
          elsif reboot_failed?(exception)
            VALID_RFC_062_EXIT_CODES[:REBOOT_FAILED]
          elsif audit_failure?(exception)
            VALID_RFC_062_EXIT_CODES[:AUDIT_MODE_FAILURE]
          else
            VALID_RFC_062_EXIT_CODES[:GENERIC_FAILURE]
          end
        end

        def reboot_now?(exception)
          resolve_exception_array(exception).any? do |e|
            e.is_a? Chef::Exceptions::Reboot
          end
        end

        def reboot_needed?(exit_code)
          exit_code == 0 && Chef::DSL::RebootPending.reboot_pending?
        end

        def reboot_failed?(exception)
          resolve_exception_array(exception).any? do |e|
            e.is_a? Chef::Exceptions::RebootFailed
          end
        end

        def audit_failure?(exception)
          resolve_exception_array(exception).any? do |e|
            e.is_a? Chef::Exceptions::AuditError
          end
        end

        def resolve_exception_array(exception)
          exception_array = [exception]
          if exception.respond_to?(:wrapped_errors)
            exception.wrapped_errors.each do |e|
              exception_array.push e
            end
          end
          exception_array
        end

        def deprecated_exit_codes(exit_code)
          !valid_rfc?(exit_code) || deprecated_rfc?(exit_code)
        end

        def deprecated_rfc?(exit_code)
          DEPRECATED_RFC_062_EXIT_CODES.values.include?(exit_code)
        end

        def valid_rfc?(exit_code)
          valid_exit_codes.include?(exit_code)
        end

        def valid_exit_codes
          VALID_RFC_062_EXIT_CODES.values
        end

        def skip_validation
          Chef::Config[:exit_status] == :disabled
        end

        def deprecation_warning
          "Chef RFC 62 (https://github.com/chef/chef-rfc/master/rfc062-exit-status.md) defines the" \
          " exit codes that should be used with Chef.  Chef::Application::ExitCode defines valid exit codes"  \
          " In a future release, non-standard exit codes will be redefined as" \
          " GENERIC_FAILURE unless `exit_status` is set to `:disabled` in your client.rb."
        end

        def notify_on_deprecation
          begin
            Chef.log_deprecation(deprecation_warning)
          rescue Chef::Exceptions::DeprecatedFeatureError
            # Have to rescue this, otherwise this unhandled error preempts
            # the current exit code assignment.
          end
        end

        def default_exit_code
          return DEPRECATED_RFC_062_EXIT_CODES[:DEPRECATED_FAILURE] if allow_deprecated_exit_code
          return VALID_RFC_062_EXIT_CODES[:GENERIC_FAILURE]
        end

      end
    end

  end
end
