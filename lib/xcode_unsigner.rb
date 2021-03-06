require_relative 'xcode'

class XcodeUnsigner
  extend CLI

  def self.unsign_xcode
    unless CLI.codesign_exists?
      # Not sure if codesign comes pre-installed on fresh macOS, so we'll check
      # Send a pull request if you think it does :)
      error 'The `codesign` tool could not be found on your system'
      return
    end

    process 'Looking for Xcode...'
    xcodes = Xcode.find_xcodes
                  .select { |xcode| xcode.version.to_f >= 8 }
                  .select(&:signed?)

    separator

    if xcodes.empty?
      error "Didn't find any Xcode 8+ installed on your system."
      return
    else
      puts notice
      puts copy_notice unless CLI.unsafe_unsign_xcode?
    end

    separator

    selection = Ask.list prompt, ['Cancel', xcodes].flatten
    return unless selection && selection != 0

    xcode = xcodes[selection - 1]

    unsign_xcodebuild = Ask.confirm "Unsign xcodebuild too?"

    if CLI.unsafe_unsign_xcode?
      new_xcode = xcode
    else
      new_xcode_path = '/Applications/Xcode-unsigned.app'
      if Dir.exist?(new_xcode_path)
        error 'Xcode-unsigned.app already exists.'
        return
      end

      process 'Copying Xcode... (this might take a while)'
      FileUtils.cp_r(xcode.path, new_xcode_path)
      new_xcode = Xcode.new(new_xcode_path)
    end

    process 'Unsigning...'
    if new_xcode.unsign_binary! &&
       (!unsign_xcodebuild || (unsign_xcodebuild && new_xcode.unsign_xcodebuild!))
      success 'Finished! 🎉'
    else
      error "Could not unsign #{File.basename(new_xcode.path)}\n"\
            'Create an issue on https://github.com/inket/update_xcode_plugins/issues'
    end
  end

  def self.notice
    [
      'Unsigning Xcode will make it skip library validation allowing it to load plugins.'.colorize(:yellow),
      '',
      'However, an unsigned Xcode presents security risks, '\
      'and will be untrusted by both Apple and your system.'.colorize(:red),
      'Please make sure that you have launched this version of Xcode at least '\
      'once before unsigning.'.colorize(:red)
    ]
  end

  def self.copy_notice
    [
      'We recommend keeping a signed version of Xcode, so this tool will:',
      '- Create a copy of Xcode.app called Xcode-unsigned.app (consider the disk space requirements)',
      '- Unsign Xcode-unsigned.app'
    ]
  end

  def self.prompt
    "Choose which Xcode.app you would like to "\
    "#{CLI.unsafe_unsign_xcode? ? '' : 'copy and '}"\
    "unsign (use arrows)"
  end
end
