class LicenseAnalyzer
  @license_acceptable = Regexp.union([/MIT/i, /LGPL/i, /Apache/i, /Ruby/i, /BSD/i,
                                      /ISO/i, /ISC/i, /Public[- ]Domain/i,
                                      /Unlicense/i, /Artistic/i, /MPL/i, /AFL/i,
                                      /CC-BY-[0-9]*/, /^project_license$/, /OpenSSL/i,
                                      /ZLib/i, /jemalloc/i, /Python/i, /PostgreSQL/i,
                                      /Info-Zip/i])
  # TODO: Re-confirm that licenses Python, Info-Zip, OpenSSL and CC-BY are
  # OK to be shipped. https://gitlab.com/gitlab-org/omnibus-gitlab/issues/2448

  @license_unacceptable = Regexp.union([/GPL/i, /AGPL/i])
  @software_acceptable = [
    'git',                # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'config_guess',       # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'pkg-config-lite',    # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'libtool',            # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'logrotate',          # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'rsync',              # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'mysql-client',       # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'repmgr',             # GPL Mere Aggregate Exception - https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation
    'blob',               # MIT Licensed - https://github.com/webmodules/blob/blob/master/LICENSE
    'callsite',           # MIT Licensed - https://github.com/tj/callsite/blob/master/LICENSE
    'component-bind',     # MIT Licensed - https://github.com/component/bind/blob/master/LICENSE
    'component-inherit',  # MIT Licensed - https://github.com/component/inherit/blob/master/LICENSE
    'domelementtype',     # BSD-2-Clause Licensed - https://github.com/fb55/domelementtype/blob/master/LICENSE
    'domhandler',         # BSD-2-Clause Licensed - https://github.com/fb55/domhandler/blob/master/LICENSE
    'domutils',           # BSD-2-Clause Licensed - https://github.com/fb55/domutils/blob/master/LICENSE
    'fsevents',           # MIT Licensed - https://github.com/strongloop/fsevents/blob/master/LICENSE
    'indexof',            # MIT Licensed - https://github.com/component/indexof/blob/master/LICENSE
    'map-stream',         # MIT Licensed - https://github.com/dominictarr/map-stream/blob/master/LICENCE
    'object-component',   # MIT Licensed - https://github.com/component/object/blob/master/LICENSE
    'select2',            # MIT Licensed - https://github.com/select2/select2/blob/master/LICENSE.md
  ]
  # readline is GPL licensed and its use was not mere aggregation. Hence it is
  # blacklisted.
  # Details: https://gitlab.com/gitlab-org/omnibus-gitlab/issues/1945#note_29286329
  @software_unacceptable = ['readline']

  def self.software_check(dependency)
    if @software_unacceptable.include?(dependency)
      ['unacceptable', 'Blacklisted software']
    elsif @software_acceptable.include?(dependency)
      ['acceptable', 'Whitelisted software']
    end
  end

  def self.license_check(license)
    if license.match(@license_acceptable)
      ['acceptable', 'Acceptable license']
    elsif license.match(@license_unacceptable)
      ['unacceptable', 'Unacceptable license']
    end
  end

  def self.acceptable?(dependency, license)
    # This method returns two values. First one is whether the software is
    # acceptable or not. Second one is the reason for that decision. This
    # information is relayed to the user for better transparency.

    software_check_status = software_check(dependency)
    return software_check_status if software_check_status # status is nil if software is unlisted

    license_check_status = license_check(license)
    return license_check_status if license_check_status # status is nil if license is unlisted

    ['unacceptable', 'Unknown license']
  end

  def self.print_status(dependency, version, license, status, reason, level)
    # level is used to properly align the output. First level dependencies
    # (level-0) have no indentation. Their dependencies, the level-1 ones,
    # are indented.
    case status
    when 'acceptable'
      if reason == 'Acceptable license'
        puts "\t" * level + "✓ #{dependency} - #{version} uses #{license} - #{reason}"
      elsif reason == 'Whitelisted software'
        puts "\t" * level + "# #{dependency} - #{version} uses #{license} - #{reason}"
      end
    when 'unacceptable'
      if reason == 'Unknown license'
        puts "\t" * level + "! #{dependency} - #{version} uses #{license} - #{reason}"
      else
        puts "\t" * level + "⨉ #{dependency} - #{version} uses #{license} - #{reason}"
      end
    end
  end

  def self.analyze(json_data)
    violations = []

    # We are currently considering dependencies in a two-level view only. This
    # means some information will be repeated as there are softwares that are
    # dependencies of multiple components and they get listed again and again.

    # Handling level-0 dependencies
    json_data.each do |library|
      level = 0
      name = library['name']
      license = library['license'].strip.delete('"').delete("'")
      version = library['version']
      status, reason = acceptable?(name, license.strip)
      print_status(name, version, license, status, reason, level)
      violations << "#{name} - #{version} - #{license} - #{reason}" if status == 'unacceptable'

      # Handling level-1 dependencies
      library['dependencies'].each do |dependency|
        level = 1
        name = dependency['name']
        license = dependency['license'].strip.delete('"').delete("'")
        version = library['version']
        status, reason = acceptable?(name, license.strip)
        print_status(name, version, license, status, reason, level)
      end
    end

    violations
  end
end
