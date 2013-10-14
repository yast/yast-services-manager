module Yast
  import 'Directory'
  import 'Mode'
  import 'SystemdTarget'

  class SystemdTargetFinish < Client
    def initialize
      textdomain 'services-manager'
    end
  end
end
