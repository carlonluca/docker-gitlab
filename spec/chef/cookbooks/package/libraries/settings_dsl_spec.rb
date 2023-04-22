require 'chef_helper'

RSpec.describe SettingsDSL::Utils do
  subject { described_class }

  describe '.hyphenated_form' do
    it 'returns original string if no underscore exists' do
      expect(subject.hyphenated_form('foo-bar')).to eq('foo-bar')
    end

    it 'returns string with underscores replaced by hyphens' do
      expect(subject.hyphenated_form('foo_bar')).to eq('foo-bar')
    end
  end

  describe '.underscored_form' do
    it 'returns original string if no hyphen exists' do
      expect(subject.underscored_form('foo_bar')).to eq('foo_bar')
    end

    it 'returns string with hyphens replaced by underscores' do
      expect(subject.underscored_form('foo-bar')).to eq('foo_bar')
    end
  end

  describe '.sanitized_key' do
    it 'returns underscored form for services specified to skip hyphenation' do
      [
        %w[gitlab-pages gitlab_pages],
        %w[gitlab-sshd gitlab_sshd],
        %w[node-exporter node_exporter],
        %w[redis-exporter redis_exporter],
        %w[postgres-exporter postgres_exporter],
        %w[pgbouncer-exporter pgbouncer_exporter],
        %w[gitlab-shell gitlab_shell],
        %w[suggested-reviewers suggested_reviewers],
        %w[gitlab-exporter gitlab_exporter],
        %w[remote-syslog remote_syslog],
        %w[gitlab-workhorse gitlab_workhorse],
        %w[gitlab-kas gitlab_kas],
        %w[geo-secondary geo_secondary],
        %w[geo-logcursor geo_logcursor],
        %w[geo-postgresql geo_postgresql],
      ].each do |input, output|
        expect(subject.sanitized_key(input)).to eq(output)
      end
    end

    it 'returns hyphenated form for services not specified to skip hyphenation' do
      [
        %w[foo-bar foo-bar],
        %w[foo_bar foo-bar],
      ].each do |input, output|
        expect(subject.sanitized_key(input)).to eq(output)
      end
    end
  end
end
