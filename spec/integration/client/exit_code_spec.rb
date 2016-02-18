require "support/shared/integration/integration_helper"
require "chef/mixin/shell_out"
require "tiny_server"
require "tmpdir"

describe "chef-client" do

  include IntegrationSupport
  include Chef::Mixin::ShellOut

  let(:chef_dir) { File.join(File.dirname(__FILE__), "..", "..", "..", "bin") }

  # Invoke `chef-client` as `ruby PATH/TO/chef-client`. This ensures the
  # following constraints are satisfied:
  # * Windows: windows can only run batch scripts as bare executables. Rubygems
  # creates batch wrappers for installed gems, but we don't have batch wrappers
  # in the source tree.
  # * Other `chef-client` in PATH: A common case is running the tests on a
  # machine that has omnibus chef installed. In that case we need to ensure
  # we're running `chef-client` from the source tree and not the external one.
  # cf. CHEF-4914
  let(:chef_client) { "ruby '#{chef_dir}/chef-client' --minimal-ohai" }

  let(:critical_env_vars) { %w{PATH RUBYOPT BUNDLE_GEMFILE GEM_PATH}.map { |o| "#{o}=#{ENV[o]}" } .join(" ") }

  when_the_repository "does not have eit_status configured" do

    def setup_client_rb
      file "config/client.rb", <<EOM
local_mode true
cookbook_path "#{path_to('cookbooks')}"
EOM
    end

    def setup_client_rb_with_audit_mode
      file "config/client.rb", <<EOM
local_mode true
cookbook_path "#{path_to('cookbooks')}"
audit_mode :audit_only
EOM
    end

    def run_chef_client_and_expect_eit_code(eit_code)
      shell_out!(
        "#{chef_client} -c \"#{path_to('config/client.rb')}\" -o 'x::default'",
        :cwd => chef_dir,
        :returns => [eit_code])
    end

    context "has a cookbook" do

      context "with a library" do

        context "which cannot be loaded" do
          before do
            file "cookbooks/x/recipes/default.rb", ""
            file "cookbooks/x/libraries/error.rb", "require 'does/not/exist'"
          end

          it "eits with GENERAL_FAILURE, 1" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 1
          end
        end

      end

      context "with an audit recipe" do

        context "which fails" do
          before do
            file "cookbooks/x/recipes/default.rb", <<-RECIPE
control_group "control group without top level control" do
  it "should fail" do
    expect(2 - 2).to eq(1)
  end
end
RECIPE
          end

          it "eits with GENERAL_FAILURE, 1" do
            setup_client_rb_with_audit_mode
            run_chef_client_and_expect_eit_code 1
          end
        end

      end

      context "with a recipe" do

        context "which throws an error" do
          before { file "cookbooks/x/recipes/default.rb", "raise 'BOOM'" }

          it "eits with GENERAL_FAILURE, 1" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 1
          end
        end

        context "with a recipe which calls Chef::Application.fatal with a non-RFC eit code" do
          before { file "cookbooks/x/recipes/default.rb", "Chef::Application.fatal!('BOOM', 123)" }

          it "eits with the specified eit code" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 123
          end
        end

        context "with a recipe which calls Chef::Application.eit with a non-RFC eit code" do
          before { file "cookbooks/x/recipes/default.rb", "Chef::Application.eit!('BOOM', 231)" }

          it "eits with the specified eit code" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 231
          end
        end

      end

    end

  end

  when_the_repository "does has eit_status configured" do

    def setup_client_rb
      file "config/client.rb", <<EOM
local_mode true
cookbook_path "#{path_to('cookbooks')}"
eit_status :enabled
EOM
    end

    def setup_client_rb_with_audit_mode
      file "config/client.rb", <<EOM
local_mode true
cookbook_path "#{path_to('cookbooks')}"
eit_status :enabled
audit_mode :audit_only
EOM
    end

    def run_chef_client_and_expect_eit_code(eit_code)
      p = shell_out(
        "#{chef_client} -c \"#{path_to('config/client.rb')}\" -o 'x::default'",
        :cwd => chef_dir,
        :returns => [eit_code])
      require 'pry'; binding.pry
    end

    context "has a cookbook" do

      context "with a library" do

        context "which cannot be loaded" do
          before do
            file "cookbooks/x/recipes/default.rb", ""
            file "cookbooks/x/libraries/error.rb", "require 'does/not/exist'"
          end

          it "eits with GENERAL_FAILURE, 1" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 1
          end
        end

      end

      context "with an audit recipe" do

        context "which fails" do
          before do
            file "cookbooks/x/recipes/default.rb", <<-RECIPE
control_group "control group without top level control" do
  it "should fail" do
    expect(4 - 4).to eq(1)
  end
end
RECIPE
          end

          it "eits with AUDIT_MODE_FAILURE, 42" do
            setup_client_rb_with_audit_mode
            run_chef_client_and_expect_eit_code 42
          end
        end

      end

      context "with a recipe" do

        context "which throws an error" do
          before { file "cookbooks/x/recipes/default.rb", "raise 'BOOM'" }

          it "eits with GENERAL_FAILURE, 1" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 1
          end
        end

        context "with a recipe which calls Chef::Application.fatal with a non-RFC eit code" do
          before { file "cookbooks/x/recipes/default.rb", "Chef::Application.fatal!('BOOM', 123)" }

          it "eits with the GENERAL_FAILURE eit code, 1" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 1
          end
        end

        context "with a recipe which calls Chef::Application.eit with a non-RFC eit code" do
          before { file "cookbooks/x/recipes/default.rb", "Chef::Application.eit!('BOOM', 231)" }

          it "eits with the GENERAL_FAILURE eit code, 1" do
            setup_client_rb
            run_chef_client_and_expect_eit_code 1
          end
        end

      end

    end

  end

end
