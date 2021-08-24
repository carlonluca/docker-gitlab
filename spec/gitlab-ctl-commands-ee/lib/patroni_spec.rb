require 'spec_helper'
require 'omnibus-ctl'
require 'optparse'

require_relative('../../../files/gitlab-ctl-commands/lib/gitlab_ctl')
require_relative('../../../files/gitlab-ctl-commands-ee/lib/patroni')

RSpec.describe 'Patroni' do
  core_commands = %w(bootstrap check-leader check-replica check-standby-leader reinitialize-replica)
  additional_commands = %w(members pause resume failover switchover restart reload)
  all_commands = core_commands + additional_commands

  command_lines = {
    'bootstrap' => %w(--srcdir=SRCDIR --scope=SCOPE --datadir=DATADIR),
    'pause' => %w(-w),
    'resume' => %w(--wait),
    'failover' => %w(--master MASTER --candidate CANDIDATE),
    'switchover' => %w(--master MASTER --candidate CANDIDATE --scheduled SCHEDULED),
    'reinitialize-replica' => %w(--wait --member MEMBER),
    'restart' => [],
    'reload' => []
  }

  command_options = {
    'bootstrap' => { srcdir: 'SRCDIR', scope: 'SCOPE', datadir: 'DATADIR' },
    'pause' => { wait: true },
    'resume' => { wait: true },
    'failover' => { master: 'MASTER', candidate: 'CANDIDATE' },
    'switchover' => { master: 'MASTER', candidate: 'CANDIDATE', scheduled: 'SCHEDULED' },
    'reinitialize-replica' => { wait: true, member: 'MEMBER' },
    'restart' => {},
    'reload' => {}

  }

  patronictl_command = {
    'members' => 'list',
    'pause' => 'pause -w',
    'resume' => 'resume -w',
    'failover' => 'failover --force --master MASTER --candidate CANDIDATE',
    'switchover' => 'switchover --force --master MASTER --candidate CANDIDATE --scheduled SCHEDULED',
    'restart' => 'restart --force fake-scope fake-node',
    'reload' => 'reload --force fake-scope fake-node'
  }

  describe '.parse_options' do
    before do
      allow(Patroni::Utils).to receive(:warn_and_exit).and_call_original
      allow(Kernel).to receive(:exit) { |code| raise "Kernel.exit(#{code})" }
      allow(Kernel).to receive(:warn)
    end

    it 'should throw error when global options are invalid' do
      expect { Patroni.parse_options(%w(patroni --foo)) }.to raise_error(OptionParser::ParseError)
    end

    it 'should throw error when sub-command is not specified' do
      expect { Patroni.parse_options(%w(patroni -v)) }.to raise_error(OptionParser::ParseError)
    end

    it 'should throw error when sub-command is not defined' do
      expect { Patroni.parse_options(%w(patroni -v foo)) }.to raise_error(OptionParser::ParseError)
    end

    it 'should recognize global options' do
      expect(Patroni.parse_options(%w(patroni -v -q members))).to include(quiet: true, verbose: true)
    end

    context 'when sub-command is passed' do
      all_commands.each do |cmd|
        it "should parse #{cmd} options" do
          cmd_line = command_lines[cmd] || []
          cmd_opts = command_options[cmd] || {}
          cmd_opts[:command] = cmd

          expect(Patroni.parse_options(%W(patroni #{cmd}) + cmd_line)).to include(cmd_opts)
        end
      end
    end

    context 'when help option is passed' do
      it 'should show help message and exit for global help option' do
        expect { Patroni.parse_options(%w(patroni -h)) }.to raise_error('Kernel.exit(0)')
        expect(Patroni::Utils).to have_received(:warn_and_exit).with(/Usage help/)
      end

      all_commands.each do |cmd|
        it "should show help message and exit for #{cmd} help option" do
          expect { Patroni.parse_options(%W(patroni #{cmd} -h)) }.to raise_error('Kernel.exit(0)')
          expect(Patroni::Utils).to have_received(:warn_and_exit).with(instance_of(OptionParser))
        end
      end
    end
  end

  describe 'additional commands' do
    before do
      allow(GitlabCtl::Util).to receive(:get_public_node_attributes).and_return({ 'patroni' => { 'config_dir' => '/fake' } })
      allow(GitlabCtl::Util).to receive(:get_node_attributes).and_return({ 'patroni' => { 'scope' => 'fake-scope', 'name' => 'fake-node' } })
      allow(GitlabCtl::Util).to receive(:run_command)
    end

    additional_commands.each do |cmd|
      it "should run the relevant patronictl command for #{cmd}" do
        Patroni.send(cmd.to_sym, command_options[cmd] || {})

        expect(GitlabCtl::Util).to have_received(:run_command).with(
          "/opt/gitlab/embedded/bin/patronictl -c /fake/patroni.yaml #{patronictl_command[cmd]}",
          user: 'root', live: false)
      end
    end
  end

  describe 'command output on non-Patroni node' do
    before do
      allow(GitlabCtl::Util).to receive(:get_public_node_attributes).and_return({ 'patroni' => nil })
      allow(GitlabCtl::Util).to receive(:get_node_attributes).and_return({ 'patroni' => nil })
    end

    additional_commands.each do |cmd|
      it "should raise errors when running command #{cmd}" do
        expect { Patroni.send(cmd.to_sym, command_options[cmd]) }.to(
          raise_error(RuntimeError, /no Patroni configuration/)
        )
      end
    end
  end

  describe '.init_db' do
    before do
      allow(GitlabCtl::Util).to receive(:run_command)
    end

    it 'should call initdb command with the specified options' do
      Patroni.init_db(command_options['bootstrap'])

      expect(GitlabCtl::Util).to have_received(:run_command).with('/opt/gitlab/embedded/bin/initdb -D DATADIR -E UTF8')
    end
  end

  describe '.copy_config' do
    before do
      allow(FileUtils).to receive(:cp_r)
    end

    it 'should call initdb command with the specified options' do
      Patroni.copy_config(command_options['bootstrap'])

      expect(FileUtils).to have_received(:cp_r).with('SRCDIR/.', 'DATADIR')
    end
  end

  describe '.leader?, .replica?, and .standyLeader?' do
    before do
      allow(GitlabCtl::Util).to receive(:get_public_node_attributes).and_return({ 'patroni' => { 'api_address' => 'http://localhost:8009' } })
      allow_any_instance_of(Patroni::Client).to receive(:get).with('/leader').and_yield(Struct.new(:code).new(leader_status))
      allow_any_instance_of(Patroni::Client).to receive(:get).with('/replica').and_yield(Struct.new(:code).new(replica_status))
      allow_any_instance_of(Patroni::Client).to receive(:get).with('/standby-leader').and_yield(Struct.new(:code).new(standby_leader_status))
    end

    context 'when node is leader' do
      let(:leader_status) { '200' }
      let(:replica_status) { '503' }
      let(:standby_leader_status) { '503' }

      it 'should identify node role' do
        expect(Patroni.leader?({})).to be(true)
        expect(Patroni.replica?({})).to be(false)
        expect(Patroni.standby_leader?({})).to be(false)
      end
    end

    context 'when node is replica' do
      let(:leader_status) { '503' }
      let(:replica_status) { '200' }
      let(:standby_leader_status) { '503' }

      it 'should identify node role' do
        expect(Patroni.leader?({})).to be(false)
        expect(Patroni.replica?({})).to be(true)
        expect(Patroni.standby_leader?({})).to be(false)
      end
    end

    context 'when node is standby leader' do
      let(:leader_status) { '503' }
      let(:replica_status) { '503' }
      let(:standby_leader_status) { '200' }

      it 'should identify node role' do
        expect(Patroni.leader?({})).to be(false)
        expect(Patroni.replica?({})).to be(false)
        expect(Patroni.standby_leader?({})).to be(true)
      end
    end
  end

  describe '.reinitialize_replica' do
    before do
      allow(GitlabCtl::Util).to receive(:get_public_node_attributes).and_return({ 'patroni' => { 'config_dir' => '/fake' } })
      allow(GitlabCtl::Util).to receive(:get_node_attributes).and_return({ 'patroni' => { 'scope' => 'fake-scope', 'name' => 'fake-node' } })
      allow(GitlabCtl::Util).to receive(:run_command)
    end

    context 'when member option is set' do
      it 'calls reinit command with the specified options to reinitialize the cluster member' do
        Patroni.reinitialize_replica(command_options['reinitialize-replica'])

        expect(GitlabCtl::Util).to have_received(:run_command).with(
          '/opt/gitlab/embedded/bin/patronictl -c /fake/patroni.yaml reinit --force --wait fake-scope MEMBER',
          user: 'root', live: true)
      end
    end

    context 'when member option is not set' do
      it 'calls reinit command with the specified options to reinitialize the current cluster member' do
        Patroni.reinitialize_replica(command_options['reinitialize-replica'].slice(:wait))

        expect(GitlabCtl::Util).to have_received(:run_command).with(
          '/opt/gitlab/embedded/bin/patronictl -c /fake/patroni.yaml reinit --force --wait fake-scope fake-node',
          user: 'root', live: true)
      end
    end
  end
end
