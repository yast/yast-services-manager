module Yast
  import 'Directory'
  import 'Mode'
  import 'ServicesManagerTarget'

  class ServicesManagerTargetFinish < Client

    module Target
      include ServicesManagerTargetClass::BaseTargets
    end

    def initialize
      textdomain 'services-manager'
    end

    def call args
      function = args.shift.to_s
      Builtins.y2milestone "Starting systemd target finish"

      case function
        when "Info"  then info
        when "Write" then write
        else Builtins.y2error "Unknown function '#{function}'"
      end
    end

    def info
      {
        'steps' => 1,
        'title' => _('Saving default systemd target...'),
        'when'  => [ :installation, :live_installation, :autoinst ]
      }
    end

    def write
      # live installation already have set default target in its config (bnc#891213)
      if ServicesManagerTarget.default_target.empty? && ! Mode.live_installation
        ServicesManagerTarget.default_target = Target::MULTIUSER
      end
      Builtins.y2milestone "Setting default target to #{ServicesManagerTarget.default_target}"
      ServicesManagerTarget.save
    end
  end
  ServicesManagerTargetFinish.new.call(WFM.Args)
end

