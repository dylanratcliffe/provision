require 'yaml'
require 'puppet_litmus'

def get_inventory_hash(inventory_full_path)
  if File.file?(inventory_full_path)
    inventory_hash_from_inventory_file(inventory_full_path)
  else
    { 'groups' => [{ 'name' => 'docker_nodes', 'nodes' => [] }, { 'name' => 'ssh_nodes', 'nodes' => [] }, { 'name' => 'winrm_nodes', 'nodes' => [] }] }
  end
end

def run_local_command(command, wd = Dir.pwd, env = {})
  stdout, stderr, status = Open3.capture3(env, command, chdir: wd)
  error_message = "Attempted to run\ncommand:'#{command}'\nstdout:#{stdout}\nstderr:#{stderr}"
  raise error_message unless status.to_i.zero?
  stdout
end

def platform_is_windows?(platform)
  # TODO: This seems sub-optimal. We should be able to override/specify what the real platform is on a per target basis
  # (plain_windows)            somewinorg/blah-windows-2019
  # (plain_windows)            myorg/some_image:windows-server
  # (bare_win_with_demlimiter) myorg/some_image:win-server-2008
  # (bare_win_with_demlimiter) myorg/win-2k8r2
  # No Match                   myorg/winderping    <--- Is this a Windows platform?
  # (plain_windows)            myorg/windows-server
  # (plain_windows)            windows-server
  # (bare_win_with_demlimiter) win-2008
  # (plain_windows)            webserserver-windows-2008
  # (bare_win_with_demlimiter) webserver-win-2008
  windows_regex = %r{(?<plain_windows>windows)|(?<bare_win_with_demlimiter>(?:^|[\/:\-\\;])win(?:[\/:\-\\;]|$))}
  platform =~ windows_regex
end

def on_windows?
  # Stolen directly from Puppet::Util::Platform.windows?
  # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
  # library uses that to test what platform it's on. In some places we
  # would use Puppet.features.microsoft_windows?, but this method can be
  # used to determine the behavior of the underlying system without
  # requiring features to be initialized and without side effect.
  !!File::ALT_SEPARATOR # rubocop:disable Style/DoubleNegation
end

def platform_uses_ssh(platform)
  # TODO: This seems sub-optimal. We should be able to override/specify what transport to use on a per target basis
  !platform_is_windows?(platform)
end

def token_from_fogfile
  fog_file = File.join(Dir.home, '.fog')
  unless File.file?(fog_file)
    puts "Cannot file fog file at #{fog_file}"
    return nil
  end
  contents = YAML.load_file(fog_file)
  token = contents.dig(:default, :vmpooler_token)
  token
end
